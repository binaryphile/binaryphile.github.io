---
layout: post
title: "Theory of Constraints in a Go Pipeline"
category: development
---

My code indexer ran fine on my Chromebook.
Then I made it parallel.
Then it OOMed.

8GB RAM. 4 cores.
The embedding model loads at 2GB.
Each concurrent worker adds 400MB.
Two workers: 2.6GB, stable.
Three workers: dead.

The Go runtime doesn't know about native memory.
GOMEMLIMIT can't help.

## Instrument first

I should have started here.
I didn't. I built the telemetry after three failed fixes.

Every 2 seconds, each pipeline stage reports utilization, starvation,
and blocking.

```
embed:       saturated  util=175%
store:       starved    util=10%
hnsw-insert: starved    util=1%
chunk-admit: blocked
```

Embed is the bottleneck. 80--98% of wall time. Everything downstream
waits. Everything upstream backs up.

Upstream producing faster than embed can consume just builds inventory.
Inventory is memory.

## The rope

A rope limits how much work enters the system based on how fast the
bottleneck drains it. A controller runs every 2 seconds, measures embed
throughput and upstream flow time, and computes a target WIP.

```
Startup:   length=64  wip=105  penetration=164%
Adapting:  length=6   wip=0    goodput=50.5/s
Stable:    length=13  wip=0    goodput=103.6/s
```

Starts generous. Burst. Tightens to 6. Settles at 13.
Embed saturated, everything else subordinated.
2.6GB RSS. No OOM.

On accelerated-linux --- 15,000 C files --- it stabilizes at 62 with
90% penetration. No oscillation.

Same code. Same controller. Same machine.

## Getting the units wrong

A file goes into chunk. Out come N chunks. Maybe 1, maybe 50.

The rope measures WIP from admission to the bottleneck. Admission sees
files. The bottleneck sees chunks.

First attempt: count items. A 50-chunk file and a 1-chunk file look
the same. Directionally correct, not precise.

Second attempt: infer chunk counts from completion ratios. Edge cases
everywhere. Zero divided by zero at startup.

Third attempt: running averages. Drifted under workload changes. The
estimate and the measurement disagreed, and I couldn't tell which was
wrong.

What worked: ask each stage what it's holding. Each one declares a
weight function. The admission stage returns `len(texts)`. No
inference. No translation. Just a count.

One problem remained. A file with 200 texts arrives when the rope
limit is 64. If oversized items block, and nothing flows, the rope
can't observe throughput to raise the limit. Deadlock.

Admit one oversized item without blocking. The rope sees elevated WIP
on the next tick. Tightens. Brief overshoot. No deadlock.

## What I'd do differently

Instrument first.

I built the telemetry after the third broken WIP adapter. Without it,
every fix was guesswork. With it, the bottleneck was always obvious.

Start on the constrained machine. 8GB forces every memory decision to
be explicit.

## Numbers

Chromebook. i5-1135G7. 8GB RAM. 4 cores.

| | era (137 Go files) | accelerated-linux (15K C) |
|---|---|---|
| Embed workers | 2 | 2 |
| Rope length | 13 | 62 |
| WIP penetration | 0% (drained fast) | 90% |
| Bottleneck | embed | embed |
| RSS | 2.6 GB | 2.2 GB |
| OOM | never | never |

Same binary. Same controller.
Two workloads. Both stable.

## Code

[toc](https://codeberg.org/binaryphile/toc) --- Theory of Constraints
pipeline control for Go.
[era](https://codeberg.org/binaryphile/era) --- the indexer.
