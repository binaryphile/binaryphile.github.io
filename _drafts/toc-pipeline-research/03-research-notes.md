# Research Notes

## Full Circle Narrative

1. **Worked on Chromebook** (pre-Mar 3): sequential indexing, simple, slow, completing.
2. **Added parallelism** (Mar 3, `8630ee8`): batch embedding + worker pool. Improved throughput. Added memory pressure.
3. **Broke on large repos** (Mar 17, OOM at 4.9GB): HNSW finalize invisible, killed by kernel.
4. **Instrumented everything** (Mar 17-19): toc stages for every concurrent operation. Found embed as drum.
5. **Elevated embed** (Mar 4, ORT): 15x throughput. But ORT adds 4.2GB native memory.
6. **Constraint moved to memory** (Mar 20): OOM at 4.8GB with E=8 workers.
7. **Memory rope** (Mar 20, `8881921`): auto-sizes concurrent embeds from MemAvailable. E=2 on Chromebook, E=64 on server.
8. **Works on Chromebook again**: same binary, no config, optimal goodput for each machine.

## gen-filter: Reducing the Input Instead of Elevating the Constraint

`ea92011` (Mar 15): `era gen-filter` analyzes git history to produce a PathFilter. Narrows accelerated-linux from 100K to ~16.8K files. This is a TOC move: instead of making the pipeline handle 100K files (elevate), reduce the input to what the constraint can handle (offload Herbie's pack).

## Key Architectural Commits with Evidence

### Before parallelism (pre-8630ee8)
- Sequential `indexFile` loop: one file at a time, embed, store.
- No WIP. No buffers. No backpressure. Memory bounded by one file at a time.
- Worked on Chromebook because peak memory was low.

### First parallelism (8630ee8, Mar 3)
- `pond` worker pool: N workers chunk + embed concurrently.
- WIP: up to N files in-flight simultaneously.
- Memory: N * (file content + chunks + vectors).
- Faster on big machines. More memory pressure.

### toc.Stage replaces pond (776f0b4, Mar 17)
- Each stage has bounded Capacity (buffer), blocks Submit when full (rope).
- Stats: ServiceTime, IdleTime, OutputBlockedTime per stage.
- First time we could see the constraint in the stats.

### Shop floor complete (4e2439b, Mar 19)
- Pipeline 1: 7 stages + batcher. Pipeline 2: 11 operators. Pipeline 3: concurrent commits.
- Every concurrent operation visible. The constraint identifiable from 2-second interval output.

### Memory rope (8881921, Mar 20)
- `call.ThrottleWeighted` limits concurrent embedFn calls.
- Budget from `readMemAvailable()` at startup.
- Same binary adapts to Chromebook (E=2) and server (E=64).

## Constraint Identification Data

From manual QA run (accelerated-linux, 2-dir filter, 215 files, ORT):

```
pipeline: git(q=65) walk(q=65) chunk(util=100% q=8)
  batch(q=32 w=51) embed(util=100% q=5)
  store(util=0% q=0) hnsw(util=0% q=0)
```

- embed: svc=1m25s, idle=3m17s (constraint -- 100% util when active)
- chunk: svc=6s, idle=8m42s (starved -- tons of excess capacity)
- store: svc=3.4s, idle=1m9s (subordinating)
- hnsw: svc=58ms, idle=1m18s (subordinating)

## Memory Measurement Data

| Config | MemAvailable | RSS | Outcome | maxConcurrent |
|---|---|---|---|---|
| E=8, no rope | 8.6GB | 4.8GB | OOM killed 5 min | 8 |
| E=2, manual | 8.6GB | 2.6GB | Stable, no OOM | 2 |
| Memory rope | 8.6GB | 2.7GB | Stable 20+ min | 2 (auto) |
| E=8, first rope (60%) | 8.6GB | 4.8GB | OOM | 7 (too many) |
| E=8, conservative rope (40%) | 8.6GB | 2.7GB | Stable | 2 |

## External Review Progression

10 /g reviews across 4 features:
- Shop floor pipeline: C+ -> fixed -> B/B+ holistic review
- ast-grep scoping: C+ -> fixed to exact files
- Dirty check: D+ (parser wrong) -> B- (parser fixed) -> B- (TOCTOU) -> B (fail-closed) -> B/B+ (non-authoritative skip SetSyncState)
- Blog outline: B- -> B+ (constraint moved, not extended)

## Conceptual Corrections Made During Session

1. "Memory is a second constraint dimension" -> "The constraint moved to memory after elevation"
2. "Buffer prevents starvation" -> "Buffer protects constraint utilization from upstream variability"
3. "Rope and backpressure are different things" -> "Rope is backpressure with a drum. The drum is what makes it TOC, not just flow control"
4. "We need to extend the model for memory" -> "The model works. We need to correctly identify which constraint is active"
5. "toc is a performance optimization" -> "toc is the goal. First understand, then seek to change"
