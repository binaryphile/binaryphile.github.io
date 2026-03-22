---
layout: post
title:  "Zero Goodput"
date:   2026-03-21 00:00:00 +0000
categories: development go toc
---

Every task I give Claude Code starts the same way. A barrage of find and grep commands. The codebase has thousands of files, and the assistant doesn't know which ones matter until it searches. I'm building [era](https://codeberg.org/binaryphile/era) to shorten that loop — a code indexer that exposes a codebase semantically rather than only by filenames and grep.

Indexing 20,000 C files requires concurrency. Concurrency on a Chromebook requires knowing what the machine can give you. And that requires seeing where the resources go.

The indexer kept dying. OOM-killed by the kernel. No application logs, no stack trace — just an OOM kill in `dmesg`. The process had two phases — streaming and finalization — and the failing phase had no instrumentation. I couldn't see what was killing it because I'd never looked there.

This post is about finding the real failure modes and building most of the control plane. The system is not yet reliably safe on the target machine. The diagnosis is done. The fix is in progress.

The machine is an i5-1135G7 Chromebook with 14.8GB RAM. ChromeOS takes its share. The Crostini Linux VM gets about 8.6GB. I could have treated the OOM as a hardware problem. But I wanted the tool to be honest about its resources — size itself to the machine it's on and finish reliably without demanding hardware I don't have.

*Companion post: [It's Mean and It Catches Things](/development/ai/collaboration/2026/03/21/its-mean-and-it-catches-things/).*

## It worked, then it didn't

Before March 2026 the indexer ran sequentially. One file at a time: read, chunk, embed, store. Slow, but it always finished.

I added parallelism. Batch embedding, worker pools, concurrent stages. Throughput improved. Memory pressure increased. The system started dying.

```
Out of memory: Killed process 18590 (era-indexer) total-vm:13625412kB, anon-rss:4719260kB
Out of memory: Killed process 16935 (era-indexer) total-vm:19798692kB, anon-rss:9352688kB
```

The failing phase was HNSW graph finalization. It ran in a goroutine after the streaming pipeline completed. It had no instrumentation. I didn't even know it was the failing phase until I let a run complete and checked `dmesg`. I'd been killing test runs before they got that far.

## Two phases, two kinds of pressure

The process has two phases. Streaming does the per-file work: walk, chunk, embed, persist. Finalization builds the indices, resolves the call graph, and publishes the database. I could see streaming. I couldn't see finalization.

During streaming, each concurrent embed worker holds ~400MB of ORT inference scratch. With 8 workers, that's ~3.2GB held simultaneously. Separately, side-effect state accumulates — document contents and call graph edges in memory maps that finalization needs later.

The memory didn't come back when streaming stopped. ORT's native allocators held their pages. When finalization began on top of that retained footprint, total demand exceeded what the OS would give. `dmesg` showed OOM kills at both 4.7GB and 9.4GB RSS across different runs — the variation likely reflects different system-wide memory pressure and VM reclaim behavior at the time of each run.

I spent all my attention on streaming because it was visibly slow. The throughput work — worktree walk, batch embedding, ORT backend — was correct improvement to a real bottleneck. But the throughput bottleneck cost me time. The memory constraint cost me everything. A run that OOMs produces nothing. Speed doesn't matter if the process can't finish.

| Failure mode | Phase | Cause | Mitigation |
|---|---|---|---|
| Concurrent ORT scratch | Streaming | 8 workers x 400MB = 3.2GB | Memory rope limits concurrency |
| Accumulated state | Finalization | In-memory maps grow with every file | Disk-backed NDJSON spill |
| Retained RSS | Finalization | RSS stays elevated after streaming | Startup sizing leaves headroom |
| go-git packfile spike | Streaming | Commit pipeline materializes packfile objects | Not yet mitigated |

## Instrumenting everything

I made every concurrent station visible. Every goroutine that runs in parallel became a `toc.Stage` with a bounded queue, blocking submit, and per-stage stats: service time, idle time, output-blocked time, queue depth.

The pipeline implements Drum-Buffer-Rope from Goldratt's Theory of Constraints. I read *The Goal* in business school and loved it. Then I did [Capsim](https://www.capsim.com/product-catalog/business-simulations/capstone) — a real-time manufacturing simulation — and couldn't apply any of it. If you didn't identify the constraint from the start, things got progressively harder and more distracting — a little mismanagement and the whole system crashed. It didn't help that it was the week before graduation, with robes and goodbyes competing for attention. Reading about constraint-first thinking and applying it under pressure turned out to be different skills. This pipeline is where I finally closed the gap.

The constraint sets the pace. Bounded queues in front of each stage buffer against upstream variability. Blocking submit on a full queue is the rope — it prevents upstream from overproducing work the constraint can't consume.

```
git -> walk -> chunk -> batcher -> embed -> store -> hnsw-insert
```

Finalization — the phase that had been invisible — got its own toc stages.

The dashboard, printed every 2 seconds:

```
pipeline: git(q=65) walk(q=65) chunk(util=100% q=8)
  batch(q=32 w=51) embed(q=5)
  store(util=0% q=0) hnsw(util=0% q=0)
```

Everything downstream of embed is idle. Everything upstream is held back. Embed's own utilization metric is misleading — 8 worker goroutines blocked on a memory semaphore all count as "busy." The starvation pattern across stages is clear.

What became visible was stage starvation and queue patterns, not perfect truth. One key metric — blocked-on-semaphore workers counted as "busy" — was semantically wrong. The cross-stage pattern still identified the bottleneck.

Before instrumentation I assumed `walk` was the bottleneck. It does I/O-heavy git tree iteration. Wrong. Walk had excess capacity. It wasn't close.

Store was idle for 53 of 60 minutes. HNSW-insert was idle for 57 of 60 minutes.

## Fixing the bottleneck

With the constraint identified, I applied Goldratt's focusing steps to embed.

**Exploit**: don't waste the bottleneck's capacity. `WeightedBatcher` batches 64 texts into a single `EmbedBatch` call. Multi-worker single-threaded inference beats single-worker multi-threaded for MiniLM-L6-v2. Measured: 239 texts/sec vs 157 texts/sec.

**Subordinate**: all other stages pace to embed. The bounded queue stays populated. Store and HNSW idle, waiting for output — correct behavior, not waste. Subordination also reduced WIP and memory pressure. Upstream produces only what the bottleneck can consume.

**Elevate**: I switched from GoMLX to ONNX Runtime. ORT brings ~2GB native memory overhead for the runtime, model, and allocator pools, plus ~400MB scratch per concurrent inference call. All outside the Go heap, invisible to the garbage collector.

## The constraint moved

After elevating embed, the system got faster. Then it died. ORT's baseline overhead raised the memory floor. Higher throughput meant accumulated state grew faster.

An external review flagged it: the constraint had moved from embed throughput to memory headroom, and I was still improving around the old one. Goldratt calls this Step 5. Don't let the previous constraint become a mental anchor.

I reapplied the steps.

**Exploit**: I moved accumulated side-effect state from in-memory maps to disposable temp NDJSON files. The Go heap holds only the current batch. The tradeoff is disk I/O and temp space management on crash cleanup.

**Subordinate**: limit concurrent embed calls to what fits in RAM. `call.ThrottleWeighted` sets the concurrency limit based on available memory at startup:

```go
const unit       = 100 << 20  // budget unit: 100MB
const base       = 2 << 30    // ~2GB: ORT runtime/model/pools + Go runtime
const embedCost  = 6          // 6 units (~600MB) per concurrent embed

avail  := readMemAvailable()  // bytes from /proc/meminfo
budget := max(embedCost, (int64(float64(avail)*0.4)-base)/unit)
E      := min(runtime.GOMAXPROCS(0), budget/embedCost)
```

The per-embed budget of 600MB is conservative — observed ORT scratch is ~400MB, with 200MB headroom for pipeline buffers, HNSW growth, and finalization. The 40% budget factor was calibrated empirically. 60% was too aggressive — OOM. 40% is conservative and stable. Manual tuning. The weakest part of the implementation.

The `max(embedCost, ...)` floor means the heuristic never chooses zero workers. On a machine where even one worker doesn't safely fit, it will OOM rather than refuse to start. This heuristic reduces one class of OOMs. It is not a proof of memory safety.

On 8.6GB available, `E = 2`. On 7.7GB available — other processes consuming more — `E = 1`. On Linux, at startup, the binary sizes embed concurrency to the current reported headroom. `MemAvailable` at startup is not the same as safe runtime headroom, especially inside Crostini under host pressure.

**Elevate**: more RAM, smaller model, subprocess isolation for ORT. Future work.

## What I got wrong

**I called memory "a second constraint dimension."** The constraint moved. Standard Step 5. The TOC model didn't need extending. My implementation needed to catch up with it.

**I collapsed buffer and rope into one mechanism.** `toc.Capacity` is both the buffer size and the blocking mechanism. For a linear pipeline this works. For fan-out/fan-in it won't. That's a gap in the implementation, not a place where DBR doesn't apply.

**I kept optimizing around the old bottleneck after it moved.** The system kept OOMing. I stopped reapplying the method that had already worked once.

## Where it stands

| State | Before | After partial mitigation |
|---|---|---|
| Workload | accelerated-linux, ~19K files | same |
| Failure | OOM during streaming (E=8) or finalization | Stable through streaming at E=1-2, 1.8-2.3GB steady-state RSS |
| Unresolved | — | go-git packfile spike to 5.4GB, memory rope not yet wired into production pipeline |

Every concurrent goroutine is now a toc stage with stats. The system reads available memory at startup and sizes concurrency accordingly.

The memory rope — the mechanism that limits concurrent embed calls to what the machine can sustain — is still being implemented. Without it, the app fails on this hardware. The instrumentation and constraint identification are done. The sizing heuristic works in testing. The remaining work is wiring the rope into the production pipeline and validating on the full corpus.

The go-git packfile spike — 5.4GB RSS traced to commit pipeline materializing packfile objects — is outside the sizing model entirely. On the target Chromebook that spike would likely trigger OOM. The startup heuristic cannot prevent transient spikes from libraries it doesn't control.

The invisible failure mode — a phase I'd never instrumented, in runs I rarely completed — cost more than any bottleneck I could see.

## What's next

- **Adaptive admission**: learn capacity from acceptance rates rather than static allocation
- **Buffer penetration monitoring**: green/yellow/red zones based on consumption rates
- **Dynamic sizing**: re-evaluate concurrency limits at runtime based on memory pressure

These are hypotheses, not results.

---

*The pipeline framework is [fluentfp/toc](https://github.com/binaryphile/fluentfp). The indexer is [era](https://codeberg.org/binaryphile/era). Both are open source.*

*Sources: Goldratt, [The Goal](https://en.wikipedia.org/wiki/The_Goal_(novel)) (1992). Tendon, [Hyper-Productive Knowledge Work](https://tameflow.com) (TameFlow). Tendon, Standing on Bits (2022). Forte Labs, [TOC 105-106: DBR at Microsoft](https://fortelabs.com/blog/theory-of-constraints-105-drum-buffer-rope-at-microsoft/).*
