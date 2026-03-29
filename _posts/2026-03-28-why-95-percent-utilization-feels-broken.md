---
layout: post
title: "Why 95% Utilization Feels Broken: A Queue Demo, Three Review Rounds, and a Better Model"
category: development
---

A queue at 95% target load is mathematically stable. A dashboard says fine.
Watch it run and your gut says broken. That gap is where queuing intuition
fails.

I built a terminal demo with Claude to show this. I designed the teaching
progression and the analogies. Claude wrote the implementation. The demo looked
right after the first draft. Three rounds of adversarial external review proved
it was teaching wrong lessons confidently.

## What the demo teaches

Target load is the ratio of arrival rate to service rate, written ρ (rho) in
queuing theory.

Three metrics tell you how a queue behaves: **throughput** (customers served per
unit time), **flow time** (how long each customer spends from arrival to
departure), and **WIP** (how many are in the system — waiting plus being
served). Little's Law ties them together: flow time = WIP / throughput. When
one gets worse, the others move with it.

The sparklines below show WIP over time. The number at the end is average flow
time. Those are the metrics to watch as we add complexity.

Each step removes one simplification: the gate, perfect regularity, randomness
on one side, both sides, the remaining headroom.

**Start with no randomness.** A sushi boat. The chef places a plate, it
circles to you, you grab it, the empty spot comes back. Nobody arrives until
there's room. No queue is possible because arrivals are gated by departures.
That's lockstep --- a gated handoff, not a standard open queue.

Now remove the gate. A merry-go-round: kids show up every 3.3 minutes whether
or not a horse is free, but each ride takes exactly 3. Arrivals are independent
of departures for the first time. A queue could form --- arrivals no longer
wait for an opening. It doesn't, because the timing is still perfectly regular.
Queuing theory calls this D/D/1 --- deterministic arrivals, deterministic
service, one server.

In the sparklines below, the low bar (▁) is the baseline --- zero WIP. Taller
blocks mean more customers in the system.

```
Lockstep:               ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  avg flow: —
Fixed Schedule (D/D/1): ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  avg flow: 0.0min
```

Flat lines. No waiting. Simple and predictable, but nothing in production
looks like this.

**Add randomness to one side.** A coffee shop. Every drink takes exactly 3
minutes. But customers arrive unpredictably --- two walk in together, then
nobody for ten minutes. The server can't absorb the bursts instantly. It forms
and drains. That's variable arrivals, fixed service (M/D/1).

Flip it. A dentist with appointments every 30 minutes. Most visits take 25.
Some run to 40. The patient who arrives on time for the next slot waits because
the previous one ran over. That's fixed arrivals, variable service (D/M/1).
Either source of variability alone creates queues, even when the server is fast
enough on average.

```
Random Arrivals (M/D/1): ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▂▃▂▁▁  avg flow: 2.1min
Random Service (D/M/1):  ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▃▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▂▁▁  avg flow: 2.0min
```

Average demand is 10% below capacity. Occasional queuing is nevertheless
visible.

**Add randomness to both sides.** A food truck. Customers show up whenever.
Some order a taco, some a custom burrito. Neither side is predictable.

```
Random Everything (M/M/1): ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▁▂▃▂▁▁▁▁▁▁▁▁▁▁▁▂▂▂▄▃▃▁▁  avg flow: 3.2min
```

That's M/M/1. Same target load. Average flow time jumped from ~2 min to 3.2.

**Push the load.** Same model, target load raised from 0.90 to 0.95. Then past
capacity to 1.5 --- demand exceeds service and the backlog grows.

```
Near Full (M/M/1, ρ=0.95):  ▁▁▁▁▁▁▁▁▁▁▂▃▂▁▁▁▁▁▁▁▃▃▄▂▁▂▃▄▃▂▅▁▃▃▁▁▁▂▁▁  avg flow: 5.8min
Overloaded (M/M/1, ρ=1.5):  ▁▂▂▂▃▃▃▂▁▂▂▂▁▁▁▂▂▂▃▅▅▅▃▃▃▃▃▃▃▂▄▅▆▇▇▇▅▅▅▇  avg flow: 7.4min*
```

\* Overloaded wait counts only completed customers. Those still queued at the
time horizon are excluded. This understates congestion.

Five percentage points of load. Nearly 2x the flow time. "95% utilized" sounds like
5% less headroom.

The overloaded sparkline climbs and doesn't come back.

In steady state, near-full is far worse than this demo shows. M/M/1 theory
predicts about 57 minutes of average flow time at ρ=0.95 with 3-minute mean
service. The demo's 5.8 minutes reflects a short cold-start run that never
reaches that regime. The nonlinear pain is real. The demo understates it.

Stable scenarios run all customers to completion before measuring. Overloaded
runs for a fixed time horizon. The full comparison:

```
Scenario                        │ target ρ │ peak WIP │ avg WIP │ avg flow
─────────────────────────────────────────────────────────────────────
Lockstep                        │      —   │      0 │   0.0 │        —
Fixed Schedule (D/D/1)          │    0.90  │      0 │   0.0 │   0.0min
Random Arrivals (M/D/1)         │    0.90  │      4 │   0.6 │   2.1min
Random Service (D/M/1)          │    0.90  │      4 │   0.6 │   2.0min
Random Everything (M/M/1)       │    0.90  │      5 │   0.8 │   3.2min
Near Full (M/M/1)               │    0.95  │      6 │   1.6 │   5.8min
Overloaded (M/M/1)              │    1.50  │     10 │   4.0 │   7.4min*
```

These lessons are only as trustworthy as the simulation behind them. The first
version looked plausible and was subtly wrong.

## Three review rounds that made it trustworthy

Each round: I sent the current plan to an external AI reviewer for adversarial
grading, evaluated the feedback, decided what to change, and had Claude
implement the fix.

### Round 1: target load 1.0 has no steady state

I'd chosen target load 1.0 as baseline. Capacity equals demand. Natural
starting point.

M/M/1 at load 1.0 has no stationary distribution. Mean queue length is
infinite. In a 50-customer run, the specific random path dominates the results,
not the underlying process. We were demonstrating seed sensitivity, not queuing
theory.

I changed it to target load 0.9 for stochastic scenarios. Added the near-full
scenario at 0.95. Overloaded at 1.5, where the demo doesn't claim steady
state.

**Principle:** The obvious parameter made validation impossible.

### Round 2: you can't verify what you assumed

Two catches.

**Circular Little's Law.** The implementation computed flow time from
WIP / throughput, then "verified" that WIP = throughput * flow time. That's
algebra, not verification.

The fix: timestamp each customer independently. Compute flow time from
timestamps. Compute average WIP from event-time integration. Check whether
WIP = throughput * flow time. The ratio is 1.00 (within rounding) for every
stable scenario:

```
Little's Law consistency check (WIP ≈ TP × FT):

Random Arrivals (M/D/1)          WIP=0.55  TP×FT=0.55  ratio=1.00
Random Service (D/M/1)           WIP=0.58  TP×FT=0.58  ratio=1.00
Random Everything (M/M/1)        WIP=0.84  TP×FT=0.84  ratio=1.00
Near Full (M/M/1, ρ=0.95)        WIP=1.57  TP×FT=1.57  ratio=1.00
```

A consistency check, not external validation. But when one side was derived
from the other, even this check was impossible.

```go
// Flow time — only over completed customers.
var totalFlow float64
var flowCount int
for _, c := range r.customers {
    if c.completion > 0 {
        ft := c.completion - c.arrival
        totalFlow += ft
        flowCount++
    }
}
if flowCount > 0 {
    m.avgFlow = totalFlow / float64(flowCount)
}

// Event-time integrated WIP.
var wipArea float64
prevTime := 0.0
prevWIP := 0
for _, e := range r.log {
    dt := e.time - prevTime
    wipArea += float64(prevWIP) * dt
    prevTime = e.time
    prevWIP = e.systemSize
}
m.avgWIP = wipArea / r.endTime
```

Flow time from timestamps. WIP from integration. Neither derived from the
other.

**"Common seeds" aren't matched traces.** Different scenarios consume random
numbers differently. The fixed-schedule scenario uses none. The
random-arrivals scenario draws only from the arrival sequence. Sharing a seed
doesn't mean scenarios see the same arrivals. Fix: pre-generate one
interarrival sequence and one service sequence. Each scenario slices what it
needs.

**Principle:** Verification that travels the same code path as computation
isn't verification.

### Round 3: simulation is not animation

The first implementation used real-time sleeps with 500ms terminal ticks. The
refresh rate was the simulation clock.

Two customers arriving 0.3 simulated minutes apart land in the same tick. We
weren't simulating random arrivals. We were simulating whatever the tick
granularity permits.

I decided on discrete-event simulation in virtual time. Run instantly. Record
everything. Animate playback separately.

```go
func runSim(cfg simConfig) simResult {
    var (
        customers []customer
        log       []logEntry
        eq        eventQueue
        queue     []int // FIFO
        busy      bool
    )
    heap.Init(&eq)

    record := func(t float64, typ eventType, custIdx, qDepth int, serverBusy bool) {
        log = append(log, logEntry{
            time: t, typ: typ, custIdx: custIdx,
            queueDepth: qDepth, serverBusy: serverBusy,
        })
    }
    // ... process events in simulated time, record everything
}
```

Playback at 360x. All metrics in simulated units --- "Avg wait: 5.8 min"
means simulated minutes, not wall-clock.

**Principle:** Coupling simulation to rendering makes both unreliable.

---

Three questions from these reviews. Is your baseline valid? Is your
verification independent of your computation? Is your clock decoupled from your
display? Believable output is not the same as a trustworthy model.

[Source code](https://github.com/binaryphile/toc/tree/master/examples/queue-demo)
