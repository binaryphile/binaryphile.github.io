# Timeline: Era Indexer Pipeline Evolution

## Pre-DBR (Mar 3-15): Sequential -> Parallel

- **Mar 3**: Profiling instrumentation. Scale architecture for 100K+ files.
- **Mar 4**: Three-stage pipeline (chunk -> embed -> store). ORT backend (15x over GoMLX). Multi-session attempted, simplified to single session.
- **Mar 8**: PathFilter for large repos. Tiered indexing. accelerated-linux feasibility investigation.
- **Mar 14**: FTS5 bulk import optimization. Batch edge insertion.
- **Mar 15**: Safety caps, PathFilter per-file includes, fluentfp v0.41.0.

**Key fact**: The indexer worked on the Chromebook before parallelism. Sequential, slow, completing. Adding multi-worker embedding and concurrent stages improved throughput but increased memory consumption.

## First DBR (Mar 16-17): toc.Stage + OOM Discovery

- **Mar 16**: First DBR task filed (#23384). Multi-worker embedding. Commit PathFilter.
- **Mar 17 02:51**: `776f0b4` -- replace pond pipeline with toc.Stage. This is the moment DBR enters the codebase.
- **Mar 17 16:04**: `3382719` -- HNSW build as toc stage, overlap FTS with finalization. The invisible phase becomes visible.
- **Mar 17 21:20**: `7f0a77e` -- memory attribution instrumentation. OOM investigation begins.
- **Mar 17 22:17**: `25964d0` -- auto-size GOMEMLIMIT, add worktree walk option.

**Key fact**: OOM at 4.9GB during HNSW finalize. The phase had no instrumentation. "We optimized the wrong thing because the failing phase was dark."

## Shop Floor (Mar 18-19): Every Phase is a Stage

- **Mar 18**: Memory-class breakdown, PathFilter integration tests, GC page release storm identified (#25017).
- **Mar 19 10:19**: `4e2439b` -- shop floor pipeline. Pipeline 1 (7 stages), Pipeline 2 (11 operators). The full DBR model.
- **Mar 19 12:05**: `ccb7e0a` -- ast-grep scoped to exact indexed files (OOM fix for C extractor).
- **Mar 19 13:27**: `22ee495` -- Pipeline 2 phase timing visible. Interval reporter stops between pipelines.
- **Mar 19 15:01**: `31be9e9` -- 12 failure injection tests.
- **Mar 19 15:34**: `06a02e0` -- worktree walk default (eliminates go-git packfile decode heap spike).
- **Mar 19 17:20**: `efc5e1e` -- dirty check + TOCTOU guard for clean-checkout invariant.
- **Mar 19 22:29**: `cadb972` -- commit pipeline concurrent with code indexing. Pipeline 3.

## Memory Constraint (Mar 20): The Constraint Moved

- **Mar 20 01:05**: `78b52f2` -- disk-backed accumulation buffer. docContents/rawCallEdges off heap.
- **Mar 20 15:43**: `8881921` -- memory rope via call.ThrottleWeighted. auto-sizes embed concurrency from MemAvailable.

**Key fact**: E=8 -> 4.8GB OOM. E=2 -> 2.6GB stable. Memory rope (maxConcurrent=2 on 8.6GB) -> 2.7GB stable 20+ min.

## Full Circle

The indexer that worked on the Chromebook, broke under parallelism, now works again -- with optimal goodput for whatever machine it runs on. Same binary, no configuration. The rope adjusts to the constraint.
