---
layout: post
title:  "Constraint-Based Indexing: Theory of Constraints in a Go Pipeline"
date:   2026-03-21 00:00:00 +0000
categories: development go toc
---

Goldratt's Five Focusing Steps are ordered for a reason. Step 1 (identify) asks you to find the constraint before you change anything. Steps 2-3 (exploit, subordinate) squeeze what you can from the current constraint. Step 4 (elevate) is the expensive one -- new architecture, new dependencies, new capacity. If you get Step 1 wrong, you pay Step 2-4 prices on the wrong target.

We did Step 1 incompletely. We saw the dominant visible bottleneck during steady-state processing (embedding) and improved it significantly. But we hadn't instrumented the phase that was killing the process (HNSW graph finalization), so we couldn't see the constraint that caused the OOM. When we finally instrumented every concurrent station, the dominant bottleneck in each phase became visible quickly.

This is the story of what that cost us, and how full instrumentation changed the game.

## It Worked, Then It Didn't

The system is a code indexer: it walks a git repository, chunks source files, generates embeddings, and persists them to vector search and full-text indices. The goal is to maximize stable completed embeddings per hour on fixed hardware. Goodput means successful completed items per unit time -- a run that OOMs produces zero goodput regardless of how fast it was running before it died.

Before March 2026, the indexer ran sequentially on a $200 Chromebook with 8GB of RAM. One file at a time: read, chunk, embed, store. Slow, but it always finished.

Then we added parallelism. Batch embedding, worker pools, concurrent stages. Throughput improved. Memory pressure increased. And the system started dying.

A brief timeline:

- **Sequential baseline** (pre-March): one file at a time, always finishes
- **Throughput optimization** (Mar 3-15): concurrent pipeline, ORT embedding backend, PathFilter to narrow 100K files to ~16.8K. Faster, but OOM-prone. A backend delegation bug meant we accidentally ran the slow GoMLX embedder instead of ORT for nearly two weeks (fixed Mar 16), muddying our performance data
- **Instrumentation** (Mar 17-19): toc stage instrumentation replaces ad-hoc pipeline. Every phase -- including finalization -- becomes a toc stage with timing and stats. System-level flow evidence (downstream starvation) reveals embed as the dominant throughput bottleneck
- **Memory safety** (Mar 20): disk-backed accumulation buffer + startup memory cap. Finishability restored

The first OOM we noticed: 4.9GB RSS. Kernel killed. No log from the indexer. `dmesg` said out of memory. The failing phase -- HNSW graph finalization -- had no instrumentation. It ran in a goroutine after the streaming pipeline completed. We didn't know what killed us because we hadn't looked there.

## The Hidden Failure Mode

Here's why the OOM was invisible for so long. The process has two phases:

1. **Streaming phase**: walk the repo, chunk files, embed, persist individual vectors (incremental HNSW inserts). This is where we spent all our attention because it was visibly slow.
2. **Finalization phase**: build the final HNSW graph index, generate full-text search indices, extract documentation, resolve call graph edges, publish the database. This ran after streaming completed.

Two kinds of memory pressure build during the streaming phase. First, each concurrent embed worker holds ~400MB of ORT inference scratch while active -- not cumulative, but concurrent. With 8 workers, that's ~3.2GB held simultaneously. Second, side-effect state accumulates over the run: document contents and call graph edges held in memory maps that finalization needs later. By the time the streaming phase finishes and finalization begins, these maps have grown with every processed file.

Why does streaming-phase memory still matter at finalization? ORT's native allocators (and the Go runtime's `mmap`-based heap) do not promptly return freed pages to the OS. RSS stays elevated after inference calls complete. So even though per-call scratch is logically freed when streaming ends, the process's resident footprint remains near its peak. Finalization then needs additional memory for HNSW graph construction and FTS indexing, pushing total demand over what the OS can provide.

The measurements were on a ChromeOS/Crostini Linux VM with 14.8GB RAM. At startup, `MemAvailable` was ~8.6GB (the rest consumed by ChromeOS, the Linux container runtime, and other processes). With 8 concurrent embed workers, peak RSS during streaming reached ~4.8GB. That left ~3.8GB for everything else in the system. When finalization began and HNSW graph construction added memory pressure, the kernel OOM-killed the process.

We didn't see this because we killed test runs before they reached finalization:

> "that took almost 4h. we were shooting for 30 min on accelerated-linux. what happened"

When we finally let a run complete on March 18 and checked `dmesg`, we found multiple prior OOM kills:

```
Out of memory: Killed process 18590 (era-indexer) total-vm:13625412kB, anon-rss:4719260kB
Out of memory: Killed process 16935 (era-indexer) total-vm:19798692kB, anon-rss:9352688kB
```

The constraint was invisible in two ways: no instrumentation on the failing phase, and the symptom only appeared in runs we rarely completed.

We did real work on the throughput bottleneck -- worktree walk, PathFilter, batch embedding, ORT backend. These were correct improvements to a real bottleneck. But the throughput bottleneck cost us time (slow indexing), while the memory constraint cost us everything (zero goodput). We were optimizing for speed while the system couldn't even finish.

## DBR in 60 Seconds

Eliyahu Goldratt's *The Goal* tells the story of Herbie, an overweight scout on an overnight hike. The troop stretches out because Herbie walks slower than everyone else. The leader puts Herbie at the front, offloads his pack, and ties a rope between Herbie and the scout behind him. The troop reaches camp before dark.

The lesson is Drum-Buffer-Rope:

- **Drum**: the constraint's achievable pace. Herbie's walking speed determines system throughput. Not the fastest scout. The slowest.
- **Buffer**: protection placed in front of the constraint, sized to absorb upstream variability. If the scout ahead of Herbie stops to tie his shoe, the gap absorbs the pause without Herbie stopping. Lost constraint time is lost system throughput -- the constraint has no excess capacity to recover it.
- **Rope**: admission control at the system's release point, synchronized to the drum. Prevents overproduction. Software engineers call this backpressure, but the rope is more specific: it's backpressure synchronized to an identified constraint. Without constraint identification, backpressure is just "the queue is full."

Where the mapping to software is partial: pipelines have fan-out/fan-in, variable work sizes, cache effects, and phase changes. A bounded queue is buffer-like. Blocking on a full queue is rope-like. But neither is automatically DBR without explicit constraint identification and system-level subordination. We use the TOC vocabulary as a design lens, not a claim of rigorous implementation.

## What We Instrumented

We made every concurrent station visible. Every goroutine that runs in parallel became a `toc.Stage` with a bounded queue, blocking submit, and per-stage stats: service time, idle time, output-blocked time, and queue depth.

The streaming pipeline:

```
git -> walk -> chunk -> batcher -> embed -> store -> hnsw-insert
```

A second pipeline handles finalization (documentation extraction, call graph resolution, FTS indexing, final HNSW graph build, database publish) -- the phase that had previously been invisible and was killing the process. Now it has its own toc stages with timing and stats. (The streaming `hnsw-insert` stage does incremental vector inserts; the finalization HNSW stage builds the navigable graph index over all inserted vectors.)

The shop floor dashboard, printed every 2 seconds:

```
pipeline: git(q=65) walk(q=65) chunk(util=100% q=8)
  batch(q=32 w=51) embed(q=5)
  store(util=0% q=0) hnsw(util=0% q=0)
```

Read it like a factory floor:

- **git/walk at q=65**: upstream has excess capacity. The rope is holding them back.
- **embed at q=5**: items queued, always consuming. (We omit embed's utilization metric here -- see caveat below.)
- **store/hnsw at util=0%**: downstream idle, waiting for embed output. Subordinating.

A caveat on embed's instrumentation: the embed stage has 8 worker goroutines (GOMAXPROCS) while a memory semaphore limits concurrent ORT calls to 1. Seven workers are blocked on the semaphore inside the stage function, which the instrumentation counts as "busy." So embed's utilization metric reflects goroutine occupancy, not ORT inference occupancy. The real evidence that embed is the system bottleneck comes from the flow pattern across stages: store and hnsw are idle 94-99% of the time, starved for input. Everything downstream is idle, everything upstream is held back. That system-level pattern is the signature of a bottleneck regardless of what the bottleneck's own utilization metric says.

Before instrumentation, we assumed `walk` was the bottleneck -- it does I/O-heavy git tree iteration. Wrong. Walk had excess capacity. It wasn't even close.

(The 8-worker / 1-effective mismatch is a design smell: worker count should be `min(GOMAXPROCS, memoryBudget)`, not unconditionally GOMAXPROCS. On a machine with more RAM, the semaphore would admit more concurrent calls and the extra workers would be useful. On this machine they waste goroutines and distort the service time metric.)

The stats told us what to fix AND what to stop fixing. The end-of-run summary from a full indexing run (19K files, 60 minutes wall time) confirms the pattern.

A note on the metrics: `svc` is cumulative wall-clock time spent inside the stage's worker function, summed across all worker goroutines. `idle` is cumulative time workers spent waiting for input. For the embed stage, this run used 8 worker goroutines (GOMAXPROCS=8) but the memory rope limited concurrent ORT calls to 1. Each worker's service time includes waiting on the memory semaphore inside the embed function, so embed's cumulative `svc` is ~8x wall time -- not a useful throughput metric for embed. The idle and service times for other stages are straightforward because they have one worker each:

```
store(svc=3m38s idle=53m)   -- 94% idle, subordinating
hnsw(svc=12s idle=57m)      -- 99% idle, subordinating
chunk(svc=6m30s idle=3s)    -- fast, never starved
```

Store was idle for 53 of 60 minutes. HNSW-insert was idle for 57 of 60 minutes. Improving either would have been wasted effort. The value of correct constraint identification is the cost of misdirected improvement you avoid.

## Fixing the Actual Bottleneck

Goldratt's steps applied to embed:

**Step 2 -- Exploit**: don't waste the bottleneck's capacity. `WeightedBatcher` batches 64 texts into a single `EmbedBatch` call for SIMD utilization. We run `IntraOpNumThreads=1` with `E=GOMAXPROCS` workers -- multi-worker single-threaded inference beats single-worker multi-threaded for MiniLM-L6-v2. Measured: 239 texts/sec vs 157 texts/sec.

**Step 3 -- Subordinate**: all other stages pace to embed. The bounded queue in front of embed stays populated. Walk has excess capacity (q=65 constantly). Store and HNSW idle, waiting for embed output. Non-bottleneck stages should have protective capacity -- that's correct behavior, not waste.

Subordination also reduced WIP and memory pressure as a side effect. Before toc stages, the indexer eagerly produced work at every stage as fast as possible, accumulating unbounded in-flight data. After, upstream produces only what the bottleneck can consume.

**Step 4 -- Elevate**: we switched from GoMLX to ONNX Runtime. Runs that previously took hours completed in minutes (exact speedup depends on batch size and concurrency; we don't have a clean A/B benchmark due to the GoMLX delegation bug described in the timeline). ORT brings significant native memory overhead: process baseline RSS rose by ~2GB after loading the ORT runtime, model, and associated allocator pools, plus ~400MB scratch per concurrent inference call. This native memory lives outside the Go heap, invisible to Go's garbage collector and GOMEMLIMIT.

## The Constraint Moved

After elevating embed, the system got faster. Then it died. OOM at 4.8GB RSS. Two effects compounded: ORT's ~2GB baseline overhead raised the memory floor, and higher throughput meant accumulated state grew faster. Same mechanics as before -- concurrent scratch plus accumulated state exceeding physical memory at finalization -- but with less headroom from the start.

We almost missed this. We kept optimizing pipeline structure -- more stages, better stats, finalization phases modeled as toc operators. An external reviewer flagged it: the dominant limiting factor had moved from embed throughput to memory headroom, and we were still improving around the old bottleneck. That's exactly the inertia Goldratt warns about in Step 5.

OOM was the symptom. The constraint was safe resident memory -- how many concurrent embed calls could physically coexist with accumulated state and leave headroom for finalization.

We reapplied the steps to the new constraint:

**Exploit**: don't waste memory. We moved accumulated side-effect state (doc contents, callee edges) from in-memory maps to disposable temp NDJSON files. The Go heap holds only the current batch, not the full history. This freed headroom for finalization.

**Subordinate**: limit concurrent embed calls to what fits in RAM. Fewer concurrent workers means less ORT scratch resident (and less retained RSS from native allocator fragmentation) when finalization begins. The disk-backed buffer independently addresses accumulated state. Both reduce peak RSS at the critical moment when finalization needs headroom.

`call.ThrottleWeighted` sets the concurrency limit based on available memory at startup:

```go
const unit       = 100 << 20  // budget unit: 100MB
const base       = 2 << 30    // ~2GB: ORT runtime/model/pools + Go runtime
const embedCost  = 6          // 6 units (~600MB) per concurrent embed

avail  := readMemAvailable()  // bytes from /proc/meminfo
budget := max(embedCost, (int64(float64(avail)*0.4)-base)/unit)
E      := min(runtime.GOMAXPROCS(0), budget/embedCost)
```

The budget has a floor of `embedCost` (6 units), guaranteeing at least one concurrent embed worker even on very constrained machines. This is operationally unsafe: on a machine where even one worker may not safely fit, the process will OOM-kill rather than refuse to start. This should be converted to fail-fast with a clear error message, or fall back to a lighter model/smaller batch size. We haven't hit that case yet, but it's a real reliability gap.

On 8.6GB available: budget = 14 units, `E = 14/6 = 2`. The concurrency limit derived from memory sets the pace that all other stages subordinate to.

**Elevate**: more RAM, smaller model, subprocess isolation for ORT. Future work.

## Startup Sizing

The heuristic estimates whether memory is likely to cap embed concurrency on this machine and sizes conservatively:

If memory budget < CPU cores: memory caps concurrency.
If CPU cores <= memory budget: embed throughput is the bottleneck. Concurrency scales to CPU.

One policy, machine-specific operating point. No per-machine configuration.

All measurements on a ChromeOS/Crostini VM (14.8GB RAM, 8 cores, ORT MiniLM-L6-v2).

**Prior runs (before memory rope):**

| Config | E | Peak RSS | Outcome |
|---|---|---|---|
| No rope | 8 | 4.8GB | OOM killed in 5 min (streaming phase) |
| 60% budget (too aggressive) | 7 | 4.8GB | OOM (streaming phase) |

Note: these early OOMs occurred during the streaming phase itself, not during finalization. With 8 concurrent embed workers, ORT scratch alone consumed ~3.2GB concurrent, leaving insufficient headroom for the Go runtime and pipeline buffers. The finalization-phase OOM described earlier in the post was a separate failure mode: lower concurrency could survive streaming but accumulated state plus retained RSS caused OOM when finalization began. Both failure modes stem from the same root cause (memory pressure from concurrent embedding) but manifest at different phases.

**Current run (memory rope, auto-selected E=1):**

Corpus: accelerated-linux. MemAvailable at startup: 7.7GB. Flow accounting: 122,724 files visited → 103,498 filtered by PathFilter → 19,226 emitted to pipeline → 16,921 indexed, 187 chunker/ast-grep errors, 2,118 files that produced no embeddable content (shell scripts, trivial headers).

Two runs on the same corpus (same machine, same configuration, auto-selected E=1):

| Metric | Run 1 | Run 2 (gctrace) |
|---|---|---|
| Wall time | 60 min | 52 min |
| Files indexed | 16,921 | 16,921 |
| Embed batches | 1,069 | 1,067 |
| Steady-state RSS | 1.8-2.3GB | 1.9-2.3GB |
| Peak RSS (transient) | 5.4GB | 5.4GB |
| Finalization: call graph | 1m 30s | 1m 21s |
| Finalization: FTS rebuild | 1m 1s | 55s |
| Finalization: HNSW build | 822ms | 552ms |
| Outcome | Completed | Completed |

Wall time varied by ~13% across runs (60 vs 52 minutes), likely due to filesystem cache warmth (run 2 followed run 1 on the same repo) and VM scheduling noise. The two runs are useful for qualitative consistency (same peak RSS, same files indexed, both completed), not precise benchmarking.

RSS over time (sampled every 2s, averaged per 5-minute window):

| Phase | Time | RSS |
|---|---|---|
| Streaming start | 0-5m | 1.6-1.9GB |
| Streaming steady state | 5-20m | 1.9-2.3GB |
| GC spike (transient) | 21m | 5.4GB peak, back to 2.3GB in 30s |
| Streaming tail | 25-55m | 1.8-1.9GB |
| Finalization | 57-60m | 1.9-2.2GB |
| Completion | 60m | Clean exit |

## The Transient Spike

The spike to 5.4GB is notable and reproducible (observed at the same magnitude in two independent runs). A diagnostic run with `GODEBUG=gctrace=1` showed a correlated Go heap burst:

```
gc 1640: 826->836->671 MB, 548ms pause  -- heap doubles
gc 1641: 1300->1307->288 MB             -- peaks at 1.3GB, GC reclaims
gc 1642: 533->538->286 MB               -- back to normal
```

A third run with heap profiling (`ERA_MEMSAMPLE_DIR`) and per-component memory tracking closed the accounting. The memSampler logs both RSS and GoPhysApprox (Go runtime's physical memory) every 2 seconds:

```
Steady state:  RSS=2.3GB  GoPhys=0.6GB  Native=1.8GB
Spike peak:    RSS=4.6GB  GoPhys=2.7GB  Native=1.8GB
Post-spike:    RSS=3.1GB  GoPhys=1.2GB  Native=1.9GB
```

Native memory (ORT model + allocator pools) stayed flat at ~1.8GB throughout. The entire observed delta is Go-managed physical memory -- GoPhysApprox jumped from 600MB to 2.7GB (+2.1GB). A sampled heap profile captured during the spike identified the dominant allocator family: **go-git packfile decode** in the commit pipeline. The top leaf allocators were `MemoryObject.Write` (97MB), `idxfile.genOffsetHash` (80MB), and `readObjectNames` (52MB); cumulative allocation under the go-git decode subtree accounts for most of the spike, with go-git materializing git objects from packfiles into memory.

This is the same heap pressure we avoided for the *code* pipeline by switching to worktree walk (reading files from the filesystem instead of decoding packfiles). But the commit pipeline still uses go-git because it needs to read commit objects, not files. The fix is either streaming commit iteration without full packfile materialization, or running the commit pipeline in a separate phase.

The startup heuristic has no mechanism to prevent this kind of transient spike. The system survived because 5.4GB was below the 7.7GB available. On the target Chromebook (~5.5GB available), this spike would likely trigger OOM.

Subprocess isolation -- running ORT embedding in a separate process that exits before finalization -- would eliminate the native memory baseline and give finalization more headroom. It would not prevent in-stream spikes during embedding itself. It addresses the cross-phase retention problem, not all memory pressure.

Memory accounting (steady state vs spike, from memSampler + heap profile run):

| Component | Steady state | During spike | Source |
|---|---|---|---|
| Native (ORT + allocators) | 1.8GB | 1.8GB | RSS - GoPhysApprox (flat) |
| Go physical memory | 0.6GB | 2.7GB | runtime/metrics GoPhysApprox |
| **Total RSS** | **2.3GB** | **4.6GB** | /proc/self/status VmRSS |

The spike is entirely on the Go-managed side of the process (native memory did not contribute), with go-git packfile decode in the commit pipeline as the dominant allocator.

Note: the 5.4GB peak RSS figure comes from runs 1 and 2 (1-second external sampling); the memSampler/pprof diagnostic run captured a 4.6GB sampled peak. The difference is likely sampling granularity and instrumentation overhead. We treat the exact peak magnitude as approximate, but the source of the spike was consistent across all three runs.

For clarity, the system has exhibited several distinct memory failure modes, each with different causes and mitigations:

| Failure mode | Phase | Cause | Mitigation |
|---|---|---|---|
| Concurrent ORT scratch OOM | Streaming | 8 workers x 400MB = 3.2GB concurrent | Memory rope limits concurrent embed calls |
| Accumulated state OOM | Finalization | In-memory maps grow with every file | Disk-backed NDJSON spill |
| Retained RSS OOM | Finalization | Go/native allocators hold pages after streaming | Startup sizing leaves headroom |
| go-git packfile spike | Streaming | Commit pipeline materializes packfile objects | Not yet mitigated; streaming iteration or separate phase needed |

For the steady-state budget: `base` (2GB) + 1 worker x `cost` (600MB) = 2.6GB estimated. Observed steady-state RSS of 1.8-2.3GB. The per-worker cost of 600MB is a conservative budget that exceeds the observed ~400MB ORT scratch per call -- the extra 200MB accounts for pipeline buffers, HNSW growth share, and headroom for finalization. The 40% budget factor adds further margin.

What this is: a startup sizing heuristic that selects a safe operating point from local hardware capacity.

What this isn't: runtime re-identification, proof of optimality, dynamic buffer management, or a control law in the formal sense.

The 40% budget factor was calibrated empirically. 60% was too aggressive -- OOM. 40% is conservative and stable. This is manual tuning, and it's the weakest part of the implementation.

Caveats: `readMemAvailable()` reads Linux `/proc/meminfo` and does not respect cgroup limits by default. The magic constants (`0.4`, `2GB`, `600MB`) need empirical recalibration across different models, batch sizes, and corpus characteristics. If other processes consume memory after startup, the sizing may be too aggressive. RSS may not promptly decrease after the streaming phase due to native allocator retention. These are real limitations of a startup-only heuristic.

## What We Got Wrong

**We called memory "a second constraint dimension."** Wrong -- the constraint moved. Standard Step 5. The TOC model didn't need extending; our implementation needed to catch up with it.

**We confused buffer and rope.** The buffer protects constraint utilization from upstream variability. The rope paces release to match the constraint. Our implementation collapses them: `toc.Capacity` is both the buffer size and the rope mechanism (Submit blocks when full). For linear pipelines this works. The concepts would need to separate for more complex topologies.

**We kept optimizing around the old bottleneck after it moved.** After elevating embed throughput, we spent cycles on pipeline structure and finalization modeling. The system kept OOMing. The embarrassing part isn't that the model failed -- it's that we stopped reapplying it.

## Design Goal: No Per-Machine Tuning

The design goal is one binary with machine-adaptive operating points. No configuration file says "small machine" or "big machine." The heuristic estimates the likely limiting factor at startup and sizes concurrency accordingly.

On the measured Crostini VM, the heuristic selected a stable operating point where earlier configurations OOMed. This is not yet a safety guarantee -- the fail-open floor (always allow at least one worker) means the system can still OOM on sufficiently constrained machines, and the go-git packfile spike is not controlled by the heuristic at all. The Chromebook (8GB RAM, 4 cores) is the target deployment -- validation there is still pending.

An obvious alternative we haven't pursued yet: subprocess isolation. If the issue is native memory retained across a phase boundary, running finalization in a separate process would reset allocator state cleanly and give a hard memory boundary. That might remove the need for fragile startup heuristics entirely. We chose the heuristic approach first because it was simpler to implement and let us keep a single process, but subprocess isolation remains a serious candidate for future work.

Most tools in this space assume abundant resources. "Requires 16GB RAM" in the docs. Designed on beefy machines, broken on modest ones. The constraint-aware approach inverts that: on the tested VM and workload, the heuristic selected a stable operating point without manual configuration. The goal is a tool that works in the development environment where you actually use it, not just on the server where it would be deployed. Whether that generalizes to other machine classes and workloads is not yet demonstrated.

## What's Next

Static constants (40% budget, 600MB per worker) needed empirical calibration and are fragile. We tried 60% first -- OOM. Adjusted to 40% -- stable. This is manual tuning, not a system that finds its own equilibrium.

Directions we're interested in but haven't implemented:

- **Adaptive admission**: learn capacity from acceptance rates rather than static allocation. `bradenaw/backpressure`'s `AdaptiveThrottle` demonstrates the approach.
- **Buffer penetration monitoring**: Goldratt's buffer management uses green/yellow/red zones based on consumption rates. We have fixed-capacity queues with no penetration tracking.
- **Dynamic sizing**: re-evaluate concurrency limits at runtime based on memory pressure, rather than fixing them at startup.

These are hypotheses, not results.

**Related work**: Reactive Streams (Akka, Project Reactor) implement demand-pull backpressure without explicit constraint identification. OpenTelemetry Collector's `memorylimiterprocessor` does memory-aware admission with soft/hard limits -- arguably the same pattern without the TOC vocabulary. In Go, `bradenaw/backpressure` provides `AdaptiveThrottle` for TCP-style capacity learning. Our `fluentfp/toc` package adds per-stage stats (service time, idle time, output-blocked time, queue depth) that make bottleneck identification possible from the data. Steve Tendon's *Standing on Bits* (2022) frames TOC for software with a taxonomy of Work Flow, Work Process, and Work Execution constraints that helped us see the invisible finalization phase as a Work Execution problem -- lack of observability preventing diagnosis.

---

*The pipeline framework is [fluentfp/toc](https://github.com/binaryphile/fluentfp). The indexer is [era](https://codeberg.org/binaryphile/era). Both are open source.*

*Sources: Goldratt, [The Goal](https://en.wikipedia.org/wiki/The_Goal_(novel)) (1992). Goldratt, Critical Chain (1997). Tendon, [Hyper-Productive Knowledge Work](https://tameflow.com) (TameFlow). Tendon, Standing on Bits (2022). Forte Labs, [TOC 105-106: DBR at Microsoft](https://fortelabs.com/blog/theory-of-constraints-105-drum-buffer-rope-at-microsoft/). [OpenTelemetry Collector memorylimiterprocessor](https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/memorylimiterprocessor/README.md). [bradenaw/backpressure](https://pkg.go.dev/github.com/bradenaw/backpressure).*
