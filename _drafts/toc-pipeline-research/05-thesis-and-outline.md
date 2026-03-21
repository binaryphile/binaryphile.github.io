# Thesis and Outline

## Thesis

A code indexer that worked on a Chromebook broke when we added parallelism. Goldratt's Theory of Constraints gave us a way to get parallelism AND stability back: instrument every concurrent station, identify the constraint, size the rope to it. The constraint moved twice -- from CPU to memory -- and the model handled both transitions without modification. The result: one control policy selects machine-specific operating points -- from an 8GB Chromebook to a 256GB server -- without per-machine tuning.

The contribution is not the theory (Goldratt, 1992). It's the concrete, instrumented translation into a Go pipeline, the discovery that the constraint moved after elevation, and the full-circle return to working on the original hardware.

## Narrative Arc

**Act 1: It Worked** (pre-Mar 3)

Sequential indexer. One file at a time: chunk, embed, store. Slow on the Chromebook (8GB, 4 cores), but completing. Peak memory bounded by one file at a time. No parallelism, no WIP, no pressure.

**Act 2: We Made It Fast** (Mar 3-15)

Worker pool (`pond`), batch embedding, ORT backend (15x over GoMLX), PathFilter to narrow 100K files to 16.8K (`gen-filter` -- offloading Herbie's pack instead of making him stronger). Multi-worker embedding: N chunks concurrently, E embed workers.

Faster on bigger machines. More memory pressure everywhere.

**Act 3: It Broke** (Mar 16-17)

OOM at 4.9GB on accelerated-linux. `dmesg` says killed. No log from the indexer. The failing phase -- HNSW graph finalization -- ran in an uninstrumented goroutine after the "pipeline" finished.

We optimized the wrong thing for a week because the failing phase was dark.

**Act 4: We Instrumented Everything** (Mar 17-19)

Picked up Goldratt. Every concurrent operation became a toc stage with buffer, stats, and rope participation. "If it runs in parallel, it's a stage with a buffer."

Three pipelines:
- Pipeline 1: git -> walk -> chunk -> batcher -> embed -> store -> hnsw (streaming)
- Pipeline 2: Start -> Tee -> [ExtDocs, CallGraph] -> Join -> EdgeResolve -> Tee -> [FTS, HNSW Finalize] -> Join -> Publish (finalization)
- Pipeline 3: commit walk -> batcher -> embed -> store (concurrent with 1+2)

The shop floor dashboard:
```
pipeline: git(q=65) walk(q=65) chunk(util=100% q=8)
  batch(q=32 w=51) embed(util=100% q=5)
  store(util=0% q=0) hnsw(util=0% q=0)
```

Embed at 100%. Everything else starved or idle. The constraint was obvious in the first 2-second stats interval. Before instrumentation, we assumed walk was the bottleneck.

**Act 5: We Applied the Five Steps** (Mar 17-20)

1. Identify: embed (100% util, everything else subordinating)
2. Exploit: WeightedBatcher (64 texts/batch for SIMD), IntraOpNumThreads=1 with E=GOMAXPROCS workers (239 vs 157 texts/sec)
3. Subordinate: rope (Capacity: 64) limits upstream. Store/HNSW idle. Walk has excess capacity.
4. Elevate: ORT (15x). But adds 4.2GB native memory.
5. Go back to Step 1: the constraint moved.

**Act 6: The Constraint Moved** (Mar 20)

After elevating embed throughput, available RAM became the limiting resource. E=8 concurrent embed calls at ~400MB each = 4.8GB = OOM. We almost missed this -- we kept optimizing pipeline structure. An external reviewer flagged it. That's the inertia Goldratt warns about.

The Five Focusing Steps applied to the new constraint (memory) just as cleanly:
1. Identify: RAM (system OOMs, zero goodput)
2. Exploit: disk-backed buffer (move accumulated state off heap), release temps early
3. Subordinate: `call.ThrottleWeighted` sizes rope to memory. Budget = 40% MemAvailable - 2GB base.
4. Elevate: more RAM, smaller model, subprocess isolation (future)
5. Repeat

Data: E=8 -> 4.8GB OOM. E=2 -> 2.6GB stable. Memory rope -> 2.7GB stable.

**Act 7: Full Circle** (Mar 20)

The same binary runs on the Chromebook (8GB) and the server (256GB). On the Chromebook, memory is the constraint: 2 concurrent embeds. On the server, embed throughput is the constraint: 64 concurrent embeds. Neither OOMs. Both complete. The rope adjusts.

The indexer that worked, then broke, now works again -- with the throughput it gained from parallelism, on the hardware it started on.

## Key Insights (earned from the data, not from theory alone)

1. **Instrument first, optimize second.** The invisible phase killed the process. Instrumentation changed the diagnosis, not just the visibility.

2. **The constraint can move.** After elevation, a different resource becomes the limiter. The Five Focusing Steps handle this natively (Step 5). The model didn't need extending.

3. **Rope implies drum.** Software engineers call it backpressure. The rope is more specific: admission control sized to the identified constraint's pace. Without knowing the drum, backpressure is just "the queue is full." With the drum, the rope is intentional system-level subordination.

4. **gen-filter is Step 4 applied to input.** Reducing 100K files to 16.8K by analyzing git history is elevating the constraint by reducing the load -- offloading Herbie's pack, not making him walk faster.

5. **The library grew from constraints.** WeightedBatcher (text-count batching), Tee/Join (fan-out/fan-in), ThrottleWeighted (memory rope) -- each primitive was extracted when a production constraint forced it. Bottom-up, not top-down.

6. **External review catches inertia.** We fell into the trap Goldratt describes: continuing to improve around the old constraint after it moved. 10 adversarial reviews across 4 features caught model errors we habituated to.

7. **One binary, any machine.** The constraint-aware rope adapts to local capacity at startup. Not "degraded mode" on small machines -- the optimal mode for that machine.

## Sections (final structure)

1. **It Worked, Then It Didn't** -- full-circle hook. Chromebook -> fast -> broken -> fixed. Define system goal: maximize stable completed embeddings per hour on fixed hardware. Goodput = successful items/hr excluding crashes.

2. **DBR in 60 Seconds** -- Herbie, drum, buffer, rope. Rope implies drum (backpressure without constraint identification is just "the queue is full"). One paragraph on where the analogy is partial (fan-out/fan-in, cache effects, variable work sizes).

3. **The Shop Floor and the Five Steps** -- merged Acts 4+5. Instrumentation AND application together, not separated. Three pipelines, stats dashboard, then immediately: identify (embed 100%), exploit (batching, workers), subordinate (rope), elevate (ORT). Each step has a commit SHA, a measurement, and a decision. Concrete, not expository.

4. **When the Constraint Moved** -- elevation -> OOM symptom -> inertia (we kept optimizing the old drum) -> external review caught it -> reapply 5FS to memory. OOM is symptom, not constraint. The constraint is safe resident memory. Policy vs physical distinction.

5. **The Control Law** -- THE A-MAKER SECTION. Pseudocode for the drum/rope decision. `E = min(cpuMax, memMax)`. ThrottleWeighted enforcement. Two-machine results table. What it is (startup release policy) and what it isn't (runtime re-identification, proof of optimality). This is the section that makes a Go developer able to implement it and a TOC reader able to verify it.

6. **What We Got Wrong** -- buffer/rope confusion, "second dimension" mistake, inertia. These corrections ARE the story and the credibility. Compress.

7. **Where We Fit** -- honest survey. Reactive Streams, OTel, bradenaw, Kanban. Where the vocabulary differs (rope implies drum). What we couldn't find (stage-level constraint stats in Go). Not overclaiming.

8. **What's Next** -- hypotheses, not results. Buffer penetration, adaptive rope, dynamic re-identification. One paragraph each.

## Dropped from insights list per review

- ~~gen-filter is Step 4 applied to input~~ (retrofitted, forced)
- ~~External review catches inertia~~ (demoted to methodological note in section 6)

## Key insights (revised, 5 not 7)

1. **Instrument first, optimize second.** We optimized the wrong station because the failing station had no telemetry.
2. **The constraint can move (Step 5 is not decorative).** After elevation, a different resource becomes the limiter. Show it with data.
3. **Rope implies drum.** Without constraint identification, backpressure is arbitrary. With the drum, the rope is intentional.
4. **The library grew from constraints.** Bottom-up extraction, visible in commit history.
5. **One policy, machine-specific operating points.** The control law adapts to local capacity.
