---
layout: post
title: "In a Blocking Pipeline, Extra WIP Caps Didn't Improve Throughput"
category: development
---

I expected per-stage WIP caps to matter for throughput. In this blocking
pipeline model, they were mostly duplicating the backpressure already
created by blocking handoffs. Release control --- how fast work enters
the pipeline --- was the only lever with a signal.

## The model

A discrete-event simulator running a 3-stage pipeline. Exponential
service times. One worker per stage. The middle stage is 10x slower
than the other two --- the bottleneck. Items enter from a source, flow
through all three stages, and exit.

When a stage finishes an item but the downstream handoff is full, the
stage blocks. The item holds the server until downstream accepts it.
This mirrors a goroutine that finishes processing and blocks on
`out <- result` before it can read its next input.

This is a toy model. It doesn't have failures, retries, external I/O,
fan-out, shifting bottlenecks, or heavy-tailed service distributions.
Each of those would change the picture. What it does have is the
blocking backpressure mechanism that makes Go channel pipelines tick.

The question: what controls throughput in this system?

My first experiment gave the simulator per-stage WIP caps --- each
stage could hold at most N items (queued + in-service + blocked).
I swept 20 values per stage across all three stages. Throughput was
nearly identical for every combination: the best and worst differed by
less than 1%, well within noise. No configuration meaningfully
outperformed any other.

That result looked wrong until I remembered what blocking handoffs do.

## The mechanism

Think of each stage as a goroutine: read from input channel, process,
send to output channel. When the output channel is full, the sender
blocks:

```go
out <- result  // blocks if out is full
```

The bottleneck drains its input more slowly than upstream produces.
The bounded handoff between stage 1 and stage 2 fills. Stage 1 blocks
trying to send into the bottleneck's full input channel. Stage 1 stops
reading from its own input. The source blocks because stage 1 stopped
accepting.

The bottleneck's absorption rate propagates upstream through blocking
handoffs until it reaches the source. Release rate is effectively
subordinated to bottleneck throughput --- not by a WIP cap, but by
blocking backpressure.

Adding a per-stage WIP limit on top of that is adding a second cap on
the same thing. The bounded channel was already doing the work.

This is not about push versus pull. A Go channel sender still pushes.
The important distinction is whether the producer is forced to slow
down when downstream fills up. A bounded channel does that immediately.
An external message queue often doesn't --- work piles up in the broker
without slowing the producer.

## Admission control: the only throughput lever

I redesigned the experiment. Instead of per-stage WIP caps, two
controls: source admission rate (how many items released per interval)
and pre-bottleneck buffer time (how much protective inventory sits in
front of the constraint).

Source admission rate was the only knob that moved throughput. (In
Theory of Constraints, this is the "rope" --- tying material release
to the constraint's pace.)

Here's what happened when I varied only the admission rate, with buffer
fixed:

Each row shows items per sim-time unit (multiply by 100 for items per
interval). The bottleneck service mean is 10, so its theoretical
capacity is 0.1 items/time or 10 items per 100-unit interval. Flow
time is WIP / throughput (Little's Law).

```
  rope  throughput  avg_wip  flow_time
     1       0.010      0.1       10
     3       0.030      0.6       20
     5       0.050      1.6       32
     7       0.070      3.0       43
    10       0.091      6.1       67
    12       0.091      6.6       73
    15       0.091      6.7       74
```

Two regimes:

**Below bottleneck capacity** (rope 1--10): throughput climbs linearly.
The bottleneck has spare capacity. More input = more output.

**At or above** (rope 10+): throughput plateaus at 0.091. The
bottleneck is saturated. More input doesn't produce more output ---
it just builds WIP and flow time. WIP doubles from 3 to 6.7 for zero
throughput gain. Flow time rises from 43 to 74.

The only throughput lever in this model is "feed the bottleneck enough."
Below that threshold, you're starving your own system. Above it, you're
accumulating inventory and inflating latency for no throughput benefit.

## Buffer: a cliff, then a plateau

Here's what happened when I varied the pre-bottleneck buffer, with
admission rate fixed:

```
  buffer       throughput  avg_wip
  0.01×svc        0.0000   183.78
  0.1×svc         0.0000   183.78
  0.5×svc         0.0000   183.78
  1×svc           0.0700     3.04
  2×svc           0.0700     3.04
  5×svc           0.0700     3.04
  10×svc          0.0700     3.04
```

```
throughput
  0.07 │     ●━━━━━━━━━━━━━━━━━━━━━━━●
       │     │
       │     │
       │     │
  0.00 │━━━━━●
       └──────────────────────────────
        0.01  0.5  1   2   5       10
              buffer (× service mean)
```

Below one service-time of buffer: the bottleneck starves completely.
Zero throughput. At one service-time or above: throughput is normal and
flat. Extra buffer beyond the minimum makes no difference.

The sharp cliff is a modeling artifact, not a general law. In this
simulator, buffer capacity is measured in work-content units based on
the bottleneck's service time. Every item has the same work content.
Capacity below one item-equivalent cannot admit even one item --- so
throughput is zero by construction, not by some smooth starvation
effect. With heterogeneous items or finer granularity, the transition
would be softer.

The real lesson is the plateau, not the cliff: once the bottleneck has
even modest protection, extra buffer is wasted inventory. In systems
with failures, variable demand, or shifting bottlenecks, "modest" would
be larger. Here, one item's worth is enough.

## When this doesn't hold

This model has one bottleneck, exponential service times, single
workers, no failures, and tightly coupled stages through bounded
blocking channels. Each of those is load-bearing:

**Async or external queues.** If the producer isn't forced to slow down
when downstream fills up, backpressure doesn't propagate. Work piles
up. WIP caps become the only throttle. This is common with message
brokers, HTTP ingestion, and decoupled microservices.

**Worker pools and in-service concurrency.** A bounded channel caps the
queue between stages, not the number of goroutines actively processing.
If you spin up 100 workers pulling from a channel, the channel cap
doesn't limit concurrent execution. WIP caps on active workers still
matter.

**Fan-out, fan-in, assembly joins.** Multiple branches converging need
synchronized release, not just backpressure. The
[assembly join semantics](https://codeberg.org/binaryphile/toc/src/branch/main/doc/assembly-join-semantics.md)
are fundamentally different from a linear pipeline.

**Failures, pauses, shifting bottlenecks.** If the bottleneck goes
down and comes back, buffer protects throughput during the gap. If the
bottleneck shifts between stages, a fixed control policy may not track.

**Heavy-tailed service times.** Exponential service is memoryless and
light-tailed. Real workloads often have occasional items that take 100x
longer. Heavy tails make buffer sizing harder and WIP control more
important.

**Non-throughput reasons for WIP caps.** Memory limits, database
connection pools, file descriptors, CPU thrashing, cancellation
responsiveness, latency SLOs, fairness. All valid. None are about
throughput.

WIP caps still matter. Just not for throughput in an already-blocking
pipeline.

## The queuing theory connection

This is the same story as [Why 95% Utilization Feels
Broken](/development/2026/03/28/why-95-percent-utilization-feels-broken.html)
in different clothes. That post showed how variability at high
utilization creates nonlinear queuing pain.

Little's Law ties it together: WIP = throughput × flow time. In this
blocking pipeline, throughput is fixed by the bottleneck once you feed
it enough. Tightening WIP reduces flow time. Loosening WIP increases
flow time. Neither changes throughput. The tradeoff is latency, not
output.

## What I actually learned

I went looking for a constraint-sensitive control pattern and found a
simpler mistake: in a pipeline with blocking handoffs, I had already
built one WIP limiter into the system. The bounded handoffs were doing
the work. Adding explicit per-stage caps was building a second gate at
the same doorway.

The useful knob was admission control --- how fast work enters the
pipeline. Below the bottleneck's capacity, more input means more output.
Above it, more input means more waiting.

WIP caps still matter for latency, memory, connection limits, and
failure isolation. They just didn't improve throughput in a system where
backpressure was already subordinating flow to the bottleneck.

[Source code: DES simulator and grid
search](https://codeberg.org/binaryphile/toc/src/branch/main/sim)
