# Blog Post: TOC in a Go Pipeline -- A Case Study in Constraint-Based Indexing

## Reframe

This is a case study, not a discovery claim. TOC/DBR gave us a useful lens for a real problem. The contribution is the concrete, instrumented translation -- not the theory. Show what happened, what the data said, where the analogy helped, and where it didn't.

## Structure

### 1. The Invisible Kill

OOM at 4.9GB during HNSW graph finalize. No log, no progress, no stats. dmesg says killed. The phase had no instrumentation -- it ran in a goroutine after the "pipeline" was done.

We optimized the wrong thing because the failing phase was dark. Instrumentation changed the diagnosis, not just the visibility.

### 2. The Lens: DBR for Software Pipelines

Introduce DBR through Herbie (TameFlow Ch 12). Map to software pipelines honestly:

- **Drum**: the identified constraint's achievable pace. In our pipeline: embed stage at 100% utilization.
- **Buffer**: protection placed before the constraint, sized to absorb upstream variability. In our pipeline: bounded queue (Capacity: 64) in front of embed.
- **Rope**: release/admission control synchronized to the drum. Software engineers call this backpressure -- same mechanism, TOC vocabulary. In our pipeline: Submit blocks when buffer full, throttling upstream.

Where the mapping is useful but partial:
- Software pipelines have fan-out/fan-in, cache effects, phase changes. Not a line of hikers.
- A bounded queue is buffer-like. Blocking on a full queue is rope-like. But neither is automatically DBR in the strong sense without explicit constraint identification and system-level subordination.
- The implementation maps to TOC more directly than we initially realized. What looked like "resource throttling" turned out to be the rope sized to a new constraint (memory) after we elevated the old one (CPU throughput). The model didn't need extending -- we needed to correctly identify which constraint was active.

Position explicitly as a Work Flow case study (Tendon's taxonomy from Standing on Bits). The invisible finalize phase was also a Work Execution constraint -- lack of observability prevented diagnosis.

### 3. Building the Shop Floor

Three concurrent pipelines, all toc-instrumented. Show the actual stats output:

```
pipeline: git(q=65) walk(q=65) chunk(util=100% q=8) batch(q=32 w=51)
  embed(util=100% q=5) store(util=0% q=0) hnsw(util=0% q=0)
```

This IS the shop floor dashboard. Read it like a factory floor:
- git/walk at capacity (65): upstream has excess capacity, rope holding
- embed at 100%: this is the constraint
- store/hnsw oscillating: starved downstream, subordinating

Pipeline 2 (finalization): the phase that killed the process is now visible with timing.
Pipeline 3 (commits): runs concurrently, own context tree.

### 4. The Five Focusing Steps, Concretely

Not as theory -- as what we actually did:

1. **Identify**: embed at 100% util. Everything else idle or oscillating. The stats made it obvious. Before instrumentation, we assumed walk was the bottleneck (it's I/O-heavy). Wrong.

2. **Exploit**: WeightedBatcher batches 64 texts for single EmbedBatch call. IntraOpNumThreads=1 with E=GOMAXPROCS workers (multi-worker single-threaded >> single-worker multi-threaded for MiniLM-L6-v2). Measured: 239 texts/sec vs 157 texts/sec.

3. **Subordinate**: all other stages pace to embed. Buffer in front of embed stays populated. Walk has excess capacity (q=65 constantly). Store and HNSW idle, waiting. This is correct -- non-constraints should have protective capacity.

4. **Elevate**: ORT gives 15-20x throughput over GoMLX for embedding. But ORT brings ~4.2GB native memory. Elevation improved the throughput constraint but surfaced a different limiting factor.

5. **Go back to Step 1 (and watch for inertia)**: after ORT elevation, the constraint moved from CPU throughput to physical memory. We almost missed this -- we kept optimizing pipeline structure (more stages, better stats) when the real limiter was now RAM. An external reviewer flagged it. That's inertia: continuing to improve around the old constraint after it has moved. The instrumentation we built for Step 1 is what eventually showed us the new constraint -- but only after we looked at the right metric (RSS, not stage utilization).

### 5. When the Constraint Moved

We elevated embed throughput (ORT, 15x over GoMLX). The system got faster. Then it died -- OOM at 4.8GB. We kept thinking of embed as "the constraint" and kept optimizing pipeline structure. An external reviewer flagged it: the constraint moved.

This is Step 5 working exactly as Goldratt described. The constraint was embed throughput. We elevated it. Now memory is the constraint. Not "a second constraint" -- THE constraint. The thing that currently prevents the system from achieving its goal (indexing the repo).

Apply the Five Focusing Steps to the new constraint:
1. **Identify**: memory. The system OOMs before completing. Each concurrent embed call uses ~400MB ORT scratch.
2. **Exploit**: don't waste memory. Disk-backed accumulation buffer moves docContents/rawCallEdges off the Go heap. Release temp resources early.
3. **Subordinate**: limit concurrent embed calls to what fits in RAM. `call.ThrottleWeighted` sizes the rope to the memory constraint. Budget = 40% of MemAvailable - 2GB base. On 8.6GB available: maxConcurrent = 2.
4. **Elevate**: more RAM, smaller model, subprocess isolation, quantization. (Future work.)
5. **Repeat**: if memory is elevated (bigger machine, lighter model), what breaks next?

The rope does the same thing it always does -- limits WIP to match the constraint. When the constraint was embed throughput, the rope limited WIP to embed's pace. Now that the constraint is memory, the rope limits WIP to what physically fits. Same mechanism, different constraint driving its length.

Data:
- E=8 (rope sized to old constraint): 4.8GB RSS, OOM killed in 5 min
- E=2 (rope sized to current constraint): 2.6GB RSS, stable, no OOM
- With memory rope (maxConcurrent=2 on 8.6GB available): stable at 2.7GB for 20+ min

The trade-off is real: tightening the rope to the memory constraint reduced throughput. The system found equilibrium -- slower but alive. That's subordination. Every non-constraint resource (CPU, disk I/O) has excess capacity it can't use because the constraint (memory) won't allow it.

Data:
- E=8: 4.8GB RSS, OOM killed in 5 min
- E=2: 2.6GB RSS, stable, no OOM
- With memory rope (maxConcurrent=2 on 8.6GB available): stable at 2.7GB for 20+ min

Tightening the memory cap directly reduced throughput. The system found equilibrium -- slower but alive. That trade-off is visible in the stats because every station is instrumented.

### 6. Buffer Management: What We Got Wrong and Right

The confusion we had (and resolved):

**Buffer**: protects constraint utilization from upstream variability. If upstream hiccups, the buffer keeps the constraint working. Lost constraint time is lost system throughput -- forever, because the constraint has no excess capacity to recover.

**Rope**: paces release at the system's ingress to match constraint throughput. Prevents upstream from overproducing WIP that consumes memory without producing throughput.

**Our implementation conflates them**: toc Capacity is both the buffer size AND the rope mechanism (Submit blocks when full). Separating these is future work.

**Buffer consumption as a signal**: buffer level alone is a lagging indicator. Level plus drain/fill rate gives a better signal for whether the constraint is protected. If the buffer drains faster than it fills, upstream has a problem. If it's always full, the constraint is slower than upstream (expected, correct). We don't yet monitor buffer penetration formally -- that's future work too.

### 7. What Exists, What Doesn't, and Where We Fit

Honest survey:

**Reactive Streams** (Akka, Project Reactor): demand-pull rope (they call it backpressure). But no explicit constraint identification, no buffer-management-relative-to-constraint vocabulary.

**OpenTelemetry Collector**: memorylimiterprocessor does memory-aware admission with soft/hard limits. This is DBR without naming it. Production-proven.

**Go rope libraries** (they call it backpressure): bradenaw/backpressure has AdaptiveThrottle (TCP-style capacity learning). Closest Go analog to adaptive rope.

**Kanban / WIP limiting**: WIP limits plus bottleneck management. TOC adds explicit constraint identification, subordination discipline, and improvement sequencing (the 5 steps).

**What we couldn't find in Go**: a library that explicitly models stages with per-stage constraint-identification stats (service time, idle time, output-blocked time, queue depth) and ties admission to the identified constraint. That's what fluentfp/toc provides. Not claiming it's the first anything -- saying it's what we needed and couldn't find off the shelf.

**The feedback loop**: the library and the indexer evolved together. The indexer needed WeightedBatcher -- so we built it in toc. The indexer needed Tee/Join for fan-out/fan-in -- so we built those. An external reviewer caught that Merge+Collector was wrong for branch recombination -- so we killed Collector and built Join with proper error matrix semantics. The indexer hit OOM -- so we added ThrottleWeighted to the call package for memory-aware admission. Each real problem in the indexer drove a new primitive in the library. The library wasn't designed top-down from TOC theory -- it was extracted bottom-up from production constraints.

### 8. What's Next (Honest)

Not "PID controllers will solve everything." Instead:

Static constants (40% budget, 600MB/worker) needed empirical calibration and are fragile across machines. We tried 60% first -- OOM. Adjusted to 40% -- stable. This is manual tuning, not a system that finds its own equilibrium.

Directions we're interested in but haven't implemented:
- Adaptive admission (bradenaw's AdaptiveThrottle learns capacity from acceptance rates)
- Buffer penetration monitoring (Goldratt's buffer management -- green/yellow/red zones)
- Dynamic worker scaling (not fixed at startup)
- einride/pid-go for continuous control if oscillation becomes a problem

These are hypotheses, not results.

### 9. Same Code, Any Machine

The same binary runs on a $200 Chromebook (8GB RAM, 4 cores) and a multi-million dollar server (256GB RAM, 64 cores). No configuration file says "small machine" or "big machine." The system reads the environment, identifies the constraint, and subordinates.

On the Chromebook: memory is the constraint. Budget allows 2 concurrent embed calls. Throughput is lower. But it completes -- no OOM.

On the server: embed throughput is the constraint. Memory is abundant. 64 concurrent embed calls. Full CPU saturation. Maximum goodput -- no OOM.

Neither machine OOMs. The Chromebook is slower. The server is faster. Both produce correct results. The rope guarantees it.

Same pipeline. Same Five Focusing Steps. The rope adjusts to whichever constraint is active on THIS machine. That's optimal goodput by definition -- the system produces at the rate its current constraint allows, with no wasted resources and no OOM kills.

Most tools in this space assume abundant resources. "Requires 16GB RAM" in the docs. Designed on beefy machines, broken on modest ones. The DBR approach inverts that: the system measures its constraint and subordinates automatically. The Chromebook isn't a degraded mode -- it's the optimal mode for that machine. The tool is useful in the development environment where you actually work, not just on the server where it would be deployed.

### 10. What We Learned

- Instrument first, optimize second. The invisible phase was the one that killed the process.
- TOC gave us a vocabulary for the conversation. "What's the constraint?" is a better question than "what's slow?"
- The constraint can starve. The buffer prevents it. The constraint has the least capacity to recover lost time -- that's why starvation is catastrophic, not why it can't happen.
- When we elevated embed throughput, the constraint moved to memory. Not "a second constraint" -- THE constraint. The Five Focusing Steps applied to the new constraint just as cleanly as to the old one. The model didn't need extending -- we needed to stop treating embed as the constraint after it wasn't.
- Static tuning is fragile. Different machines need different constants. Dynamic adaptation is the right direction.
- External adversarial review caught model errors we habituated to.
- The mapping from TOC to software is useful but partial. State it honestly and it becomes more credible.

## Sources

- Goldratt, *The Goal* (1992)
- Goldratt, *Critical Chain* (1997)
- Tendon, *Hyper-Productive Knowledge Work* (TameFlow) -- Ch 12, Ch 18
- Tendon, *Standing on Bits* (2022)
- Forte Labs TOC 105-106 (DBR at Microsoft)
- OpenTelemetry Collector memorylimiterprocessor
- bradenaw/backpressure, einride/pid-go
- fluentfp/toc

## Output

Blog post. Include pipeline diagrams (mermaid), actual stats output, memory data table, before/after measurements. Show the limits of the model alongside its utility.

## Verification

Would someone who has read The Goal recognize the pattern without rolling their eyes? Would a Go developer know what to instrument and why? Does it earn every claim with data?
