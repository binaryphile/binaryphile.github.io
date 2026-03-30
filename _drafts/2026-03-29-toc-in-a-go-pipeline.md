---
layout: post
title: "Theory of Constraints in a Go Pipeline"
category: development
---

My code indexer worked on my Chromebook until I made it fast.

The slow version had parallel chunking but serial embedding — one
worker converting chunks into vectors while seven others waited for
it. Three minutes for 84 Go files. It always finished. Then I made
embedding concurrent too. Five times faster — and then the operating
system killed it.

The Chromebook has 8GB of RAM. The embedding model occupies 2GB just
sitting in memory. Each concurrent worker needs another 400MB of
scratch space. My memory budget calculated that seven workers would
fit. It was wrong. It counted the model and the per-worker scratch but
not the pipeline buffers between stages, not the search graph growing
in memory, not the commit indexer running alongside. Seven workers
pushed past 4.8GB. The OS killed the process.

Two workers at 2.6GB is what actually fits. I added a memory-weighted
semaphore that limits concurrent workers based on available RAM. That
fixed the OOM.

## What the telemetry showed

I built per-stage telemetry a week after the semaphore. Every two
seconds, every stage reports how busy it is, how much time it spends
with nothing to do, and how much time it spends blocked waiting for
the next stage to accept its output.

Embedding was the bottleneck — 80 to 98 percent of wall time on every
repo I tested. Everything upstream was blocked against it. Everything
downstream was waiting for it. Having a bottleneck is normal. The
question is what to do about the stages piling up behind it.

## The wrong unit

The semaphore limited workers. The pipeline also had per-stage buffer
limits, but they were static — they didn't respond to how fast
embedding was consuming. So I needed a limit that tracked embedding's
throughput.

The question was what to count. A file enters the pipeline and gets
split into chunks — maybe one, maybe fifty. Those chunks get batched,
embedded, stored, and inserted into a graph. I started by counting
files. When the count dropped, less accumulated. But a file that
produces fifty chunks and a file that produces one chunk both counted
as one.

Next I proposed estimating chunk counts from completion ratios. An
external reviewer saw the problem before I coded it: "You're inferring
inventory from completions. That's backwards." At startup, nothing has
finished.

## The limit

A controller reads how many chunks per second embedding completes and
how long chunks spend in transit from admission to embedding. It
multiplies them to get a target: how many chunks should be in the
pipeline right now.

At startup, 64 chunks allowed. The first burst overshot — 105 in
flight. Within a few ticks the controller tightened to 6, then settled
at 13. 2.6GB of memory. The Chromebook hummed.

I ran the same binary on a subset of a kernel source tree — about a
hundred C files filtered from 15,000. The controller settled at 62
chunks in flight. No oscillation. No tuning. Same machine.

## What worked for counting

Each stage declares a function that returns the cost of an item passing
through it. The admission stage returns the number of embeddable chunks
the file produced. The embedding stage returns the number of chunks in
its batch. The controller reads what stages report. No inference.

But one edge remained. A heavily documented file can produce hundreds
of chunks. If it arrives when the controller's limit is 64, it blocks.
If it blocks, nothing flows. If nothing flows, the controller can't
measure throughput to raise the limit. Deadlock.

The fix was to let one oversized file through without blocking. The
controller sees the spike on the next tick, tightens, and adapts.

## What I'd do differently

Build the telemetry before the first memory budget, not a week after.

Start on the smallest machine. Eight gigabytes leaves no room to be
wrong about memory.

| | 166 files (era) | ~100 files (kernel subset) |
|---|---|---|
| Workers | 2 | 2 |
| Chunks in flight (steady) | 13 | 62 |
| Memory | 2.6 GB | 2.2 GB |
| Killed by OS | never | never |

Same binary. Same controller.

The pipeline is built with [toc](https://codeberg.org/binaryphile/toc),
a Go library for Theory of Constraints pipeline control. The indexer is
[era](https://codeberg.org/binaryphile/era).
