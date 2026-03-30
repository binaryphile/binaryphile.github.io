---
layout: post
title: "Theory of Constraints in a Go Pipeline"
category: development
---

My code indexer worked on my Chromebook until I made it fast.

The slow version had parallel chunking but serial embedding — one
worker converting chunks into vectors while seven others waited for
it. Three minutes for 84 Go files. It always finished. I made
embedding concurrent too. Five times faster. Then the operating system
killed it.

The Chromebook has 8GB of RAM. The embedding model — the neural network
that turns text into vectors — occupies 2GB just sitting in memory.
Each concurrent worker needs another 400MB of scratch space. My memory
budget calculated that seven workers would fit. It was wrong. It
counted the model and the workers but not the thousands of chunks
accumulating between pipeline stages, not the search graph growing in
the background, not the commit indexer running alongside. Seven workers
pushed past 4.8GB. The OS killed the process.

Two workers at 2.6GB is what actually fits. I needed to make sure the
pipeline never tried to hold more.

## The wrong unit

The pipeline has eight stages. Files enter at one end. Vectors come out
the other. In between, a file gets split into chunks — maybe one, maybe
fifty — and those chunks get batched, embedded, stored, and inserted
into a graph. The stage that converts chunks into vectors is the
slowest by far. It consumes 80 to 98 percent of the total time. Every
other stage spends most of its time waiting.

I needed to limit how many chunks could be in the pipeline at once.
Fewer chunks in flight means less memory. But I had to measure how many
were in flight, and the pipeline doesn't count in one unit. Files enter
at the top. Chunks flow through the middle. Batches of chunks flow
through the bottom.

I counted files. It worked — when the count dropped, memory dropped.
But a file that produces fifty chunks and a file that produces one
chunk both counted as one. The limit was blunt. It kept the Chromebook
alive but couldn't tell me how much memory was actually in use.

I proposed estimating chunk counts from completion ratios — if ten
files produced three hundred chunks, maybe the next ten would too. An
external reviewer saw the problem before I coded it: "You're inferring
inventory from completions. That's backwards." At startup, nothing
has finished. The estimate would be meaningless.

## The thing I should have built first

I stopped guessing and built telemetry.

Every two seconds, every stage in the pipeline reports three numbers:
how busy it is, how much time it spends with nothing to do, and how
much time it spends blocked waiting for the next stage to accept its
output.

The picture was unambiguous. The embedding stage was working flat out.
The storage stage had nothing to do most of the time. The graph
insertion stage had nothing to do almost all of the time. Everything
upstream of embedding was blocked, waiting for embedding to take more
work.

One stage working. Five stages waiting. The upstream stages were
blocked because they'd already produced more chunks than embedding
could handle, and those chunks were sitting in memory.

## The limit

The fix was to stop upstream from producing faster than embedding could
consume.

A controller reads the embedding stage's throughput — how many chunks
per second it completes — and the time chunks spend in transit from
admission to embedding. It multiplies them to get a target: how many
chunks should be in the pipeline right now.

At startup, 64 chunks allowed. The first burst overshot — 105 chunks
in flight. Within a few ticks the controller tightened to 6, then
settled at 13 as its estimate converged. 2.6GB of memory. The
Chromebook hummed.

I ran the same binary on a subset of a kernel source tree — about a
hundred C files filtered from 15,000. The controller settled at 62
chunks in flight. No oscillation. No tuning. Same machine.

## What finally worked for counting

Each stage declares a function that returns the cost of an item passing
through it. The admission stage — a pass-through between the chunker
and the batcher — returns the number of embeddable chunks the file
produced. The embedding stage returns the number of chunks in its
batch. The controller reads these numbers directly. No inference, no
estimation, no translation between units.

One edge remained. A file with 200 chunks arrives when the controller's
limit is 64. If it blocks, nothing flows. If nothing flows, the
controller can't measure throughput. If it can't measure throughput, it
can't raise the limit. Deadlock.

The fix: let one oversized file through without blocking. The
controller sees 200 chunks suddenly in flight, tightens, and adapts on
the next tick.

## What I'd do differently

Build the telemetry before the first fix, not after.

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
