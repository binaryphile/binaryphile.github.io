---
layout: post
title: "Theory of Constraints in a Go Pipeline"
category: development
---

My code indexer worked on my Chromebook until I made it fast.

The slow version processed 84 Go files in three minutes. Embedding
dominated — 315ms per text, single-threaded. I added concurrent
workers and a pipeline. Throughput jumped 5x on my work machine. The
Chromebook OOMed.

I spent two weeks fixing that OOM. I tried three different approaches
to controlling how much work the pipeline held in flight. All three
were wrong. The fix, when I found it, was four lines of code. But I
couldn't write those four lines until I could see what the pipeline
was doing, and I didn't build that visibility until after I'd failed
three times. That's the story I want to tell.

## The problem I couldn't see

The Chromebook has 8GB of RAM and 4 cores. ORT loads a 2GB embedding
model. Each concurrent worker adds 400MB of native scratch memory —
memory the Go runtime can't see and GOMEMLIMIT can't limit. My
initial memory budget said seven workers would fit. It was wrong. It
counted ORT scratch but not pipeline buffers, not the HNSW graph
growing in memory, not the commit indexer running alongside. Seven
workers hit 4.8GB and the OS killed the process.

I knew the fix was to limit concurrency. I didn't know how much. So I
guessed. I tried three different ways to estimate how much work was in
the pipeline, and all three produced numbers I couldn't trust.

The first counted items. But a file that produces 50 chunks and a file
that produces one chunk both counted as one item. The second inferred
chunk counts from completion ratios — zero divided by zero at startup.
The third used running averages that drifted when the workload changed.
The estimate and the measurement disagreed, and I couldn't tell which
was wrong.

After the third failure I stopped and built telemetry. Every two
seconds, every pipeline stage reports its utilization, starvation, and
blocking ratio. The picture it showed was unambiguous:

```
embed:       saturated  util=175%
store:       starved    util=10%
hnsw-insert: starved    util=1%
chunk-admit: blocked
```

Embed was the bottleneck. Always had been. Everything downstream sat
idle waiting for it. Everything upstream was backed up against it. And
everything upstream that was backed up was holding memory.

## The four lines

Once I could see the bottleneck, the fix was obvious. Don't let
upstream produce faster than embed can consume.

A controller runs every two seconds. It reads embed's throughput and
the time items spend in transit upstream. It multiplies them to get a
target: how many chunks should be in flight right now. Then it limits
admission to that number.

On the Chromebook, indexing this repo:

```
Startup:   rope=64  wip=105  penetration=164%
Adapting:  rope=6   wip=0    goodput=50.5/s
Stable:    rope=13  wip=0    goodput=103.6/s
```

It starts permissive — 64 chunks allowed in flight. The first burst
overshoots. Within a few ticks it tightens to 6, then settles at 13
as the throughput estimate converges. Embed runs saturated. Everything
else is subordinated. 2.6GB RSS. No OOM.

I ran the same binary on accelerated-linux, a kernel tree with 15,000
C files. The controller stabilized at 62 chunks in flight, 90%
utilization of the limit. No oscillation, no tuning. Same machine.

## What made the fix possible

Not the controller. The telemetry.

The three failed approaches all tried to model the pipeline from the
outside — inferring what was happening from aggregate numbers. The
telemetry let me stop modeling and start observing. Each stage reports
what it's holding. The controller reads those reports. No inference,
no estimation, no translation between unit domains. Just a count.

The hardest part was the unit mismatch. A file enters the chunk stage.
Out come N chunks — maybe one, maybe fifty. Admission counts files.
The bottleneck counts chunks. I needed a stage between them whose only
job was to weigh each file in chunks as it passed through. An identity
stage. A shim. It does no work, but it gives the controller a number
it can trust.

## What I'd do differently

Build the telemetry first. I wrote it after three failures. Every one
of those failures would have been caught in minutes if I could see
per-stage utilization. I couldn't, so each failure took days.

Start on the smallest machine. The Chromebook's 8GB forced me to
account for every allocation. The work machine had enough headroom to
hide the problem.

| | era (137 Go files) | accelerated-linux (15K C) |
|---|---|---|
| Embed workers | 2 | 2 |
| Target WIP | 13 | 62 |
| WIP penetration | 0% (drained fast) | 90% |
| Bottleneck | embed | embed |
| RSS | 2.6 GB | 2.2 GB |
| OOM | never | never |

Same binary. Same controller. Two workloads. Both stable.

The pipeline is built with [toc](https://codeberg.org/binaryphile/toc),
a Go library for Theory of Constraints pipeline control. The indexer is
[era](https://codeberg.org/binaryphile/era).
