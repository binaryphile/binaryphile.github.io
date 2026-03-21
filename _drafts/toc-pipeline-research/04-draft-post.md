---
layout: post
title:  "Theory of Constraints in a Go Pipeline"
date:   2026-03-21 00:00:00 +0000
categories: development go toc
---

Our code indexer died on a Chromebook. 4.9GB RSS, kernel killed, no log. `dmesg` said OOM. We didn't know what phase it was in because the failing work -- HNSW graph finalization -- ran in an uninstrumented goroutine after the "pipeline" was done.

We optimized the wrong thing for a week because the failing phase was dark. That's when we picked up Goldratt.

## The Lens

Eliyahu Goldratt's *The Goal* tells the story of Herbie, an overweight scout on an overnight hike. The troop stretches out because Herbie walks slower than everyone else. The leader puts Herbie at the front, offloads his pack, and ties a rope between Herbie and the scout behind him. The troop reaches camp before dark.

The lesson is Drum-Buffer-Rope:

- **Drum**: the constraint sets the pace. Herbie's walking speed determines system throughput. Not the fastest scout. The slowest.
- **Buffer**: work placed in front of the constraint protects it from upstream variability. If the scout ahead of Herbie stops to tie his shoe, the gap between them absorbs the pause without Herbie having to stop. Lost constraint time is lost forever -- Herbie can't walk faster to make up for it.
- **Rope**: a physical limit on how far ahead the lead scout can get. Prevents overproduction. Software engineers call this backpressure, but the rope is more specific: it's admission control synchronized to the drum's pace.

We mapped this to our indexing pipeline:

```
git -> walk -> chunk -> batcher -> embed -> store -> hnsw
```

Every stage became a `toc.Stage` -- our Go implementation of a DBR station. Each stage has a bounded queue (the buffer), blocks on Submit when full (the rope), and reports stats every 2 seconds:

```
pipeline: git(q=65) walk(q=65) chunk(util=100% q=8)
  batch(q=32 w=51) embed(util=100% q=5)
  store(util=0% q=0) hnsw(util=0% q=0)
```

Read that like a factory floor dashboard:
- `git(q=65) walk(q=65)` -- upstream at capacity. The rope is holding.
- `embed(util=100%)` -- this is the constraint. 100% utilization.
- `store(util=0%) hnsw(util=0%)` -- downstream starving, waiting for embed output. Subordinating.

Before instrumentation, we assumed `walk` was the bottleneck -- it does I/O-heavy git tree iteration. Wrong. The stats showed embed was the drum in the first 2-second interval.

## The Five Focusing Steps, Concretely

Goldratt's improvement process isn't abstract. Here's what we actually did:

**Step 1: Identify.** Embed at 100% utilization. Everything else idle or oscillating. The per-stage stats made it obvious.

**Step 2: Exploit.** Don't waste the constraint's capacity. We batch 64 texts into a single `EmbedBatch` call for SIMD utilization. We run `IntraOpNumThreads=1` with E=GOMAXPROCS workers -- multi-worker single-threaded inference beats single-worker multi-threaded for small models like MiniLM-L6-v2 (measured: 239 texts/sec vs 157 texts/sec).

**Step 3: Subordinate.** All other stages pace to embed. The buffer in front of embed (Capacity: 64) stays populated. Walk has excess capacity (`q=65` constantly). Store and HNSW idle, waiting for embed output. This is correct -- non-constraints should have protective capacity.

**Step 4: Elevate.** We switched from GoMLX to ONNX Runtime. 15-20x throughput improvement on embedding. But ORT brings ~4.2GB of native memory for the model and inference scratch.

**Step 5: Go back to Step 1.** After elevating embed throughput, the system got faster. Then it died -- OOM at 4.8GB on accelerated-linux (100K-file C repo, 16.8K files after PathFilter).

We almost missed this. We kept optimizing pipeline structure -- more stages, better stats, finalization phases as toc operators. The constraint had moved, and we were still improving around the old one. An external reviewer flagged it.

That's exactly the inertia Goldratt warns about.

## When the Constraint Moved

The constraint was embed throughput. We elevated it. Now the constraint is available RAM.

Not "a second constraint dimension." Not "an infrastructure constraint orthogonal to throughput." THE constraint. The thing currently preventing the system from achieving its goal: indexing the repo successfully.

We reapplied the Five Focusing Steps:

**Step 1: Identify.** Available RAM is the limiting resource. Each concurrent embed call uses ~400MB ORT scratch memory. The system OOMs before completing -- which means zero successful throughput.

**Step 2: Exploit.** Don't waste memory. We moved accumulated side-effect state (doc contents, callee edges) from in-memory maps to disposable temp files -- a disk-backed buffer. The Go heap holds only the current batch, not the full history. We release temp resources early.

**Step 3: Subordinate.** Limit concurrent embed calls to what fits in RAM. `call.ThrottleWeighted` sizes the rope to the memory constraint:

```go
budget := int(float64(avail)*0.4) - baseOverhead
maxConcurrent := budget / perWorkerCost
embedFn = call.ThrottleWeighted(budget, batchCost, embedFn)
```

Budget = 40% of `MemAvailable` minus 2GB base overhead. Each concurrent embed costs 6 units (~600MB including ORT scratch, pipeline buffers, HNSW graph growth).

On 8.6GB available: `maxConcurrent = 2`.

**Step 4: Elevate.** More RAM. Smaller model. Subprocess isolation for ORT. Model quantization. (Future work.)

**Step 5: Repeat.** If memory is elevated (bigger machine, lighter model), what breaks next?

The rope does the same thing it always does -- limits WIP to match the constraint. When the constraint was embed throughput, the rope limited WIP to embed's pace. Now that the constraint is memory, the rope limits WIP to what physically fits. Same mechanism, different constraint driving its length.

The data:

| Config | RSS | Outcome |
|---|---|---|
| E=8 (rope sized to old constraint) | 4.8GB | OOM killed in 5 min |
| E=2 (rope sized to current constraint) | 2.6GB | Stable, no OOM |
| Memory rope (auto-sized, 8.6GB avail) | 2.7GB | Stable 20+ min |

Tightening the rope to the memory constraint reduced throughput. The system found equilibrium -- slower but alive. That's subordination. Every non-constraint resource (CPU, disk I/O) has excess capacity it can't use because the constraint (memory) won't allow it.

## Same Code, Different Machines

The same binary runs on a $200 Chromebook (8GB RAM, 4 cores) and a production server (256GB RAM, 64 cores).

On the Chromebook: memory is the constraint. The rope allows 2 concurrent embed calls. Throughput is lower. It completes. No OOM.

On the server: embed throughput is the constraint. Memory is abundant. The rope allows 64 concurrent embed calls. Full CPU saturation. Maximum goodput. No OOM.

Neither machine OOMs. Both produce correct results. The rope adjusts to whichever constraint is active on THIS machine.

Most tools in this space assume abundant resources. "Requires 16GB RAM" in the docs. Designed on beefy machines, broken on modest ones. The constraint-aware approach inverts that: the system reads its environment at startup, identifies the active constraint, and subordinates. The Chromebook isn't running in degraded mode -- it's running in the optimal mode for that machine.

## What We Got Wrong

**Buffer vs rope confusion.** We initially conflated these. The buffer protects constraint utilization -- it keeps the constraint working when upstream has hiccups. The rope paces release to match the constraint -- it prevents overproduction. In our implementation, `toc.Capacity` currently serves both roles (the bounded queue IS the buffer, and blocking on a full queue IS the rope). For a linear pipeline this works. The concepts are distinct and would need to separate for more complex topologies.

**"Memory is a second dimension."** We spent time trying to extend the TOC model -- framing memory as an orthogonal constraint, or an infrastructure limit, or shared tooling. None of those framings were right. The model didn't need extending. The constraint simply moved after we elevated embed throughput, and we needed to stop treating embed as the constraint after it wasn't.

**Inertia.** After elevating embed, we kept adding pipeline stages and optimizing finalization phases. The system kept OOMing. An external adversarial reviewer pointed out we were improving around the old constraint. The embarrassing part isn't that the model failed -- it's that we stopped reapplying it.

## Building the Library from Production Constraints

The pipeline framework (`fluentfp/toc`) and the indexer evolved together. Each production constraint drove a new primitive:

- The indexer needed text-count batching (not file-count) → `WeightedBatcher`
- The indexer needed parallel finalization branches → `Tee` (synchronous broadcast) + `Join` (branch recombination with error matrix)
- An external reviewer caught that our original fan-in operator (`Merge` + `Collector`) was wrong for branch recombination → killed `Collector`, built `Join` with strict 1:1 semantics
- The indexer hit OOM → `call.ThrottleWeighted` for memory-aware admission

The library wasn't designed top-down from TOC theory. It was extracted bottom-up from production constraints. Each primitive exists because a recurring problem forced it.

## Where We Fit

We couldn't find a Go library that explicitly models stages with per-stage constraint-identification stats (service time, idle time, output-blocked time, queue depth) and ties admission to the identified constraint.

Pieces exist everywhere:
- **Reactive Streams** (Akka, Project Reactor): demand-pull rope (they call it backpressure). But no explicit constraint identification.
- **OpenTelemetry Collector**: `memorylimiterprocessor` does memory-aware admission. This is DBR without naming it.
- **Go libraries**: `bradenaw/backpressure` has `AdaptiveThrottle` (TCP-style capacity learning). Closest Go analog to an adaptive rope.
- **Kanban/WIP limiting**: WIP limits plus bottleneck management. TOC adds explicit constraint identification, subordination discipline, and improvement sequencing.

Steve Tendon's *Standing on Bits* (2022) frames TOC for software engineering and distinguishes Work Flow constraints (our pipeline stages), Work Process constraints (deployment/release policy), and Work Execution constraints (implementation quality). Our case study is a Work Flow story -- but the invisible HNSW finalize phase was also a Work Execution constraint: lack of observability prevented diagnosis.

## What's Next

Static constants (40% budget, 600MB per worker) needed empirical calibration and are fragile. We tried 60% first -- OOM. Adjusted to 40% -- stable. This is manual tuning, not a system that finds its own equilibrium.

Directions we're interested in but haven't implemented:
- **Adaptive admission**: `bradenaw/backpressure`'s `AdaptiveThrottle` learns capacity from acceptance rates
- **Buffer penetration monitoring**: Goldratt's buffer management distinguishes green/yellow/red zones based on buffer consumption
- **Dynamic rope**: `toc.Options.RopeFunc` that re-evaluates WIP limits at runtime based on memory pressure or constraint throughput changes
- **PID control**: continuous feedback on buffer consumption rate, using `einride/pid-go`, if oscillation becomes a problem

These are hypotheses, not results.

## What We Learned

Instrument first, optimize second. The invisible phase was the one that killed the process.

TOC gave us a vocabulary for the conversation. "What's the constraint?" is a better question than "what's slow?"

The constraint can starve. The buffer prevents it. The constraint has the least capacity to recover lost time -- that's why starvation is catastrophic, not why it can't happen.

After we elevated embed throughput, the constraint moved to memory. The Five Focusing Steps applied to the new constraint just as cleanly. The model didn't need extending -- we needed to stop treating embed as the constraint after it wasn't.

The mapping from TOC to software is useful but partial. We said so honestly, and that made it more credible. A bounded queue is buffer-like. Blocking on a full queue is rope-like. But neither is DBR in the strong sense without explicit constraint identification and system-level subordination. Our implementation is closer to DBR than most software pipelines, but it's not a complete translation. Stating that earns more trust than overclaiming.

---

*The pipeline framework is [fluentfp/toc](https://github.com/binaryphile/fluentfp). The indexer is [era](https://codeberg.org/binaryphile/era). Both are open source.*

*Sources: Goldratt, The Goal (1992). Goldratt, Critical Chain (1997). Tendon, Hyper-Productive Knowledge Work (TameFlow). Tendon, Standing on Bits (2022). Forte Labs, [TOC 105-106: DBR at Microsoft](https://fortelabs.com/blog/theory-of-constraints-105-drum-buffer-rope-at-microsoft/). [OpenTelemetry Collector memorylimiterprocessor](https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/memorylimiterprocessor/README.md). [bradenaw/backpressure](https://pkg.go.dev/github.com/bradenaw/backpressure). [einride/pid-go](https://github.com/einride/pid-go).*
