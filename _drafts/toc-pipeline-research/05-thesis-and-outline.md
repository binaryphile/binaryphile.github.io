# Thesis and Outline

## Thesis

Goldratt's Five Focusing Steps are ordered for a reason. Step 1 (identify the constraint) is cheap -- add instrumentation. Steps 2-4 (exploit, subordinate, elevate) are expensive -- engineering changes, architecture decisions, dependency upgrades. If you get Step 1 wrong, you pay Steps 2-4 prices on the wrong target.

We did Step 1 incompletely. We identified the throughput constraint correctly (embed) and improved goodput significantly. But we hadn't instrumented the phase that was killing the process (HNSW finalize), so we couldn't see the constraint that caused the OOM. When we finally instrumented every concurrent station, the active constraint was obvious in the first 2-second stats interval. After elevation, the constraint moved to memory, and the same instrumentation caught that too.

The leverage in Goldratt's process comes from Step 1: if you identify the constraint under partial observability, you can improve throughput on one dimension while being blind to the constraint that's actually killing your system. This is the story of what that cost us, and how full instrumentation changed the game.

## Structure

Every section supports the thesis. The arc: skimped on Step 1 -> paid the price -> did Step 1 right -> everything followed.

### 1. It Worked, Then It Didn't

Hook: a code indexer that worked on a $200 Chromebook broke when we made it fast. OOM at 4.9GB. `dmesg` says killed. No log from the indexer.

Define upfront: System = document ingestion through chunking, embedding, persistence. Goal = maximize stable completed embeddings per hour on fixed hardware. Goodput = successful completed items per unit time (OOM = zero goodput).

The kicker: the failing phase -- HNSW graph finalization -- had no instrumentation. It ran in a goroutine after the "pipeline" was done. We didn't know what killed us because we hadn't instrumented it. We'd been told instrumenting it was over-engineering.

### 2. The Price of Incomplete Step 1

We did real, valuable work on the throughput constraint. Worktree walk (avoid packfile decode), PathFilter (reduce file count), gen-filter (analyze git history to select relevant files), batch embedding, ORT backend -- all improved goodput. These were correct Steps 2-4 applied to a real throughput constraint (embed).

But the OOM kept happening. Because the OOM wasn't a throughput problem. It was a memory problem in a phase we hadn't instrumented (HNSW finalize). We were improving throughput under partial observability -- unable to see the constraint that was actually killing the process.

The cost: every hour spent on throughput improvements while blind to the memory constraint was time NOT spent on the thing that was crashing the system. The throughput work had value, but we couldn't see that a different constraint needed attention first. That's what incomplete Step 1 costs you -- not wasted effort, but delayed diagnosis of the constraint that matters most.

### 3. DBR in 60 Seconds

Herbie story (brief). Drum = constraint's pace. Buffer = protection in front of constraint. Rope = admission control sized to the drum (software engineers call this backpressure, but rope implies drum -- without constraint identification, backpressure is just "the queue is full").

Where the mapping is partial: software pipelines have fan-out/fan-in, variable work sizes, phase changes. State it honestly.

### 4. Doing Step 1 Right

We instrumented every concurrent station. Every goroutine that runs in parallel became a toc stage with buffer, stats, and rope participation.

Three pipelines. The shop floor dashboard:
```
pipeline: git(q=65) walk(q=65) chunk(util=100% q=8)
  batch(q=32 w=51) embed(util=100% q=5)
  store(util=0% q=0) hnsw(util=0% q=0)
```

Embed at 100%. Everything else idle or subordinating. The constraint was obvious in the first 2-second interval. We'd been optimizing walk. Walk was at capacity with excess -- it wasn't even close to being the constraint.

The stats told us what to fix AND what to stop fixing. Six stations that looked like they could be improved were irrelevant. Evidence-based prioritization: the ROI of correct constraint identification is the entire cost of misdirected improvement that you avoid.

### 5. Steps 2-4, This Time on the Right Target

Now applied to the actual constraint (embed):

- **Exploit**: WeightedBatcher batches 64 texts for SIMD. IntraOpNumThreads=1, E=GOMAXPROCS workers (239 vs 157 texts/sec).
- **Subordinate**: rope (Capacity: 64). Store/HNSW idle. Walk has excess capacity.
- **Elevate**: ORT (15x over GoMLX). But adds 4.2GB native memory.

Each step has a commit, a measurement, and a result. Concrete.

### 6. Step 5: The Constraint Moved

After elevating embed, available RAM became the active constraint. OOM at 4.8GB was the SYMPTOM revealing our release policy exceeded memory capacity. The constraint was safe resident memory, not "OOM."

We almost missed this -- inertia. We kept optimizing pipeline structure (more stages, better stats) around the old drum. An external reviewer flagged it. That's exactly the trap Goldratt warns about in Step 5.

Reapply the Five Steps to the new constraint:
1. Identify: safe resident memory (~400MB per concurrent embed)
2. Exploit: disk-backed accumulation buffer (move side-effect state off heap)
3. Subordinate: `call.ThrottleWeighted` sizes rope to memory budget
4. Elevate: more RAM, smaller model (future)
5. Repeat

### 7. The Control Law

The A-maker section. Pseudocode:

```
E = min(cpuMax, max(1, (avail * 0.4 - base) / perEmbed))
```

Two-machine results table:

| Machine | E | Peak RSS | Outcome |
|---|---|---|---|
| Chromebook (8GB) | 2 | 2.7GB | Completes |
| Server (256GB) | 64 | full saturation | Completes |

What it is: startup release policy. One control law, machine-specific operating point.
What it isn't: runtime re-identification. Proof of optimality. Dynamic buffer management.

The 40% budget factor was calibrated empirically (60% = OOM, 40% = stable). This is the weakest part -- manual tuning of the safety margin.

### 8. What We Got Wrong

Compressed. The corrections earn credibility:
- We were told not to instrument every stage. If we'd listened, we'd still be debugging the wrong bottleneck at higher cost and risk.
- We called memory "a second constraint dimension." Wrong -- the constraint moved. The model didn't need extending; our implementation needed to catch up.
- We confused buffer and rope. Buffer protects constraint utilization. Rope paces release. Our implementation collapses them (acceptable for linear pipelines, noted as simplification).

### 9. Where We Fit

Brief honest survey. Reactive Streams (rope without drum). OpenTelemetry (DBR without naming it). bradenaw/backpressure (closest Go analog). Kanban (WIP limits; TOC adds constraint identification and improvement sequencing).

What we couldn't find in Go: stage-level stats that identify the constraint and tie admission to it.

### 10. What's Next

One paragraph each. Hypotheses, not results:
- Buffer penetration monitoring (green/yellow/red)
- Adaptive rope (learn capacity from acceptance rates)
- Dynamic constraint re-identification at runtime
