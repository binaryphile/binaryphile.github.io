---
layout: post
title: "Why 95% Utilization Feels Broken: Building a Queuing Demo That Didn't Lie"
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
queuing theory. The scenarios progress from no randomness (lockstep, fixed
schedule) through randomness on one side (arrivals or service) to both sides
random, then push toward and past capacity. The parenthetical labels are
queuing shorthand: M is random, D is fixed, the number is servers. M/D/1 means
random arrivals, fixed service, one server.

These are cold-start finite runs, not steady-state measurements, so the
numbers will be milder than theory predicts for the higher-load scenarios.

```
Scenario                        │ target ρ │ served │ cust/hr │ peak q │ avg q │ avg wait
─────────────────────────────────────────────────────────────────────────────────────────
Lockstep                        │      —   │     10 │    20.0 │      0 │   0.0 │        —
Fixed Schedule (D/D/1)          │    0.90  │     10 │    16.5 │      0 │   0.0 │   0.0min
Random Arrivals (M/D/1)         │    0.90  │     50 │    16.1 │      4 │   0.6 │   2.1min
Random Service (D/M/1)          │    0.90  │     50 │    17.0 │      4 │   0.6 │   2.0min
Random Everything (M/M/1)       │    0.90  │     50 │    15.7 │      5 │   0.8 │   3.2min
Near Full (M/M/1)               │    0.95  │     80 │    16.2 │      6 │   1.6 │   5.8min
Overloaded (M/M/1)              │    1.50  │     43 │    21.5 │     10 │   4.0 │   7.4min*
```

\* Overloaded wait counts only completed customers. Those still queued at the
time horizon are excluded. This understates congestion.

Queue depth over time:

```
Lockstep:                       ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
Fixed Schedule (D/D/1):         ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
Random Arrivals (M/D/1):        ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▂▃▂▁▁
Random Service (D/M/1):         ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▃▂▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▂▂▁▁
Random Everything (M/M/1):      ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▂▁▂▃▂▁▁▁▁▁▁▁▁▁▁▁▂▂▂▄▃▃▁▁
Near Full (M/M/1, ρ=0.95):      ▁▁▁▁▁▁▁▁▁▁▂▃▂▁▁▁▁▁▁▁▃▃▄▂▁▂▃▄▃▂▅▁▃▃▁▁▁▂▁▁
Overloaded (M/M/1, ρ=1.5):      ▁▂▂▂▃▃▃▂▁▂▂▂▁▁▁▂▂▂▃▅▅▅▃▃▃▃▃▃▃▂▄▅▆▇▇▇▅▅▅▇
```

**Target load 0.95 is stable. It looks broken.** Same model as random
everything above, target load raised from 0.90 to 0.95. Five percentage
points. Nearly 2x the wait. "95% utilized" sounds like 5% less headroom. The
delay says otherwise. Look at the sparkline.

**Randomness creates the queues. Load amplifies them.** Add randomness to
arrivals alone and queues appear at 10% below capacity. Add it to service
alone --- same thing. Both sides together makes swings deeper. Without
randomness, the queue never forms. In these single-server runs, variability
creates waiting. Load makes it worse.

**Past the tipping point, nothing helps.** Demand exceeds capacity. Backlog
grows without bound. No steady state. You already knew overloaded queues grow.
That's what makes the near-full scenario unsettling --- it grows too, and it's
supposed to be fine.

These lessons are only as trustworthy as the simulation behind them. The first
version looked plausible and was subtly dishonest.

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

**Circular Little's Law.** The implementation computed average wait from
L = lambda * W, then "verified" L = lambda * W. That's algebra, not
verification.

The fix: timestamp each customer independently. Compute
wait from timestamps. Compute queue length from event-time integration. Check
whether L_q = lambda * W_q. Ratio is 1.00 for every stable scenario:

```
Little's Law consistency check (L_q ≈ λ × W_q):

Random Arrivals (M/D/1)          L_q=0.55  λW_q=0.55  ratio=1.00
Random Service (D/M/1)           L_q=0.58  λW_q=0.58  ratio=1.00
Random Everything (M/M/1)        L_q=0.84  λW_q=0.84  ratio=1.00
Near Full (M/M/1, ρ=0.95)        L_q=1.57  λW_q=1.57  ratio=1.00
```

A consistency check, not external validation. But when one side was derived
from the other, even this check was impossible.

```go
// Avg wait (W_q) — only over completed customers.
var totalWait float64
var waitCount int
for _, c := range r.customers {
    if c.completion > 0 {
        w := c.serviceStart - c.arrival
        totalWait += w
        waitCount++
    }
}
if waitCount > 0 {
    m.avgWait = totalWait / float64(waitCount)
}

// Event-time integrated queue depth (L_q).
var queueArea float64
prevTime := 0.0
prevDepth := 0
for _, e := range r.log {
    dt := e.time - prevTime
    queueArea += float64(prevDepth) * dt
    prevTime = e.time
    prevDepth = e.queueDepth
}
m.avgQ = queueArea / r.endTime
```

W_q from timestamps. L_q from integration. Neither derived from the other.

**"Common seeds" aren't matched traces.** Different scenarios consume random
numbers differently. The fixed-schedule scenario uses none. The
random-arrivals scenario draws only from the arrival sequence. Sharing a seed doesn't mean scenarios see
the same arrivals. Fix: pre-generate one interarrival sequence and one service
sequence. Each scenario slices what it needs.

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

**Principle:** Coupling simulation to rendering makes both dishonest.

---

About 1000 lines of Go. Three review rounds and 20 polish passes before the
first commit. This post went through its own cycle --- adversarial grading
caught a misleading hook, an overclaimed thesis, a table that contradicted the
title. External review catches what self-review misses. True for simulations.
True for prose.

Three questions from these reviews. Is your baseline valid? Is your
verification independent of your computation? Is your clock decoupled from your
display? All three mistakes still produced believable output.

[Source code](https://github.com/binaryphile/toc/tree/master/examples/queue-demo)

