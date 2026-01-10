---
layout: post
title: "Agans Debugging Guide"
date: 2026-01-09 18:00:00 -05:00
categories: [ debugging, software-engineering ]
---

A practical guide to David Agans' debugging methodology, extracted from *Debugging: The 9 Indispensable Rules for Finding Even the Most Elusive Software and Hardware Problems* (2002).

---

Agans' book is a hidden gem from 2002 that remains completely relevant today. The nine rules seem obvious when you read them—but that's exactly the point. When debugging takes hours instead of minutes, it's because we forgot something fundamental: we guessed instead of looking, changed three things at once, or didn't write down what we tried. This guide is my debugging checklist for when I'm stuck and need to remember what I'm probably neglecting.

---

## 1. The Goal: Find What's Wrong, Fast

> "This book tells you how to find out what's wrong with stuff, quick."

Debugging is different from prevention (quality processes) and detection (testing). It starts when you have a bug report and ask, "How the heck did that happen?"

**The two key insights:**
1. When bugs take a long time to find, it's because we neglected a fundamental rule
2. People who excel at debugging naturally apply these rules; those who struggle don't

These rules aren't obvious in practice. Knowing them isn't enough—you must *remember* and *apply* them under pressure.

---

## 2. The Nine Rules

| # | Rule | Core Idea |
|---|------|-----------|
| 1 | Understand the System | Read the manual. Know what's supposed to happen. |
| 2 | Make It Fail | Reproduce it reliably. Can't fix what you can't see. |
| 3 | Quit Thinking and Look | Stop guessing. Instrument and observe. |
| 4 | Divide and Conquer | Binary search. Narrow the search space. |
| 5 | Change One Thing at a Time | Scientific method. Control variables. |
| 6 | Keep an Audit Trail | Write it down. The detail you ignore matters. |
| 7 | Check the Plug | Question assumptions. Is it even on? |
| 8 | Get a Fresh View | Ask for help. Report symptoms, not theories. |
| 9 | If You Didn't Fix It, It Ain't Fixed | Verify the fix. See the failure stop. |

---

## 3. Rule 1: Understand the System

> "Read the manual. It'll tell you to lubricate the trimmer head on your weed whacker so that the lines don't fuse together."

**The story:** A microprocessor ignored interrupts. After hours of debugging at 1 AM, reading page 37 of the data book revealed: "The chip will interrupt on the first deselected clock strobe." The design had combined clock with address lines—which worked for the copied design (no interrupts) but broke for this one.

**What to understand:**
- What the system is supposed to do
- How it's designed
- Why it was designed that way
- What each block and interface does

**Read everything cover to cover.** The section you skip is where the bug hides.

### Know What's Reasonable

If you don't know that low-order bytes come first in Intel PCs, you'll think your data got scrambled. If you've never heard a chain saw, you might think that noise is the problem.

### Know Your Tools

| Tool Type | What It Shows | What It Misses |
|-----------|---------------|----------------|
| Source debugger | Logic errors | Timing, multithread issues |
| Profiler | Timing | Logic flaws |
| Analog scope | Noise, glitches | Can't store much data |
| Logic analyzer | Lots of data | Can't see noise |

### Look It Up

> "Don't guess. Look it up. Be like Einstein, who never remembered his own phone number."

Detailed information exists somewhere. Pinouts, function parameters, timing specs—don't trust your memory.

---

## 4. Rule 2: Make It Fail

> "Do it again so you can look at it, so you can focus on the cause, and so you can tell if you fixed it."

**The story:** A TV pong game had an intermittent bug when the ball bounced off the practice wall. Watching the scope while playing was impossible. Solution: connect the paddle voltage to the ball's position—an automatic player. The game played itself, the scope could be watched, and the bug was found quickly.

**Three reasons to make it fail:**
1. So you can look at it while it happens
2. So you can focus on the cause
3. So you can verify the fix

### Start at the Beginning

Note the machine state going into your sequence. Try to start from a known state—a freshly rebooted computer, a cold engine.

### Stimulate the Failure

**Good:** Spray a hose on a leaky window to make it leak on demand.

**Bad:** "Simulating" the failure by changing the mechanism. If your word processor drops paragraphs and you build a disk-writing test program, you might cause a *new* failure and waste time chasing it.

> "You have enough bugs already; don't try to create new ones."

### Intermittent Bugs

When a bug happens 1 in 10 times, you don't know *exactly* how you made it fail. Hidden factors:
- Initial conditions
- Input data
- Timing
- Outside processes
- Temperature
- Network traffic
- Phase of the moon

**What to do:**
1. Try to control random factors
2. Capture information on every run (debug logs)
3. Compare good runs to bad runs
4. Look for things *always* associated with failure

**The car story:** A car made a whining noise, but only on cold mornings, only at 25-30 mph, only for the first 10 minutes. The dealer couldn't reproduce it at 11 AM when it was 37 degrees. They hadn't made it fail, so they had no chance of finding the problem.

### "But That Can't Happen"

When an engineer says "that can't happen," they mean *their assumed failure mechanism* can't happen. But the failure *did* happen. The next step: make it fail in the engineer's presence.

**Ice cream story:** A 1976 Volare wouldn't start after buying three-bean tofu mint chipped-beef ice cream, but started fine after vanilla or chocolate. Why? Unusual flavors must be hand-packed, which takes time—enough for the carbureted engine to suffer vapor lock in summer heat.

---

## 5. Rule 3: Quit Thinking and Look

> "It is a capital mistake to theorize before one has data." —Sherlock Holmes

**The story:** A slave microprocessor occasionally failed checksum after downloading. Junior engineers ran a "loopback" test—write data, read it back—and it always passed. They concluded the problem was memory timing and spent months building a fix board. It didn't help.

The senior engineer hooked up a logic analyzer and put known data through: "00 55 AA FF". What he saw wasn't "00 54 AA FF" (corrupted data), but "00 55 55 AA FF" (repeated data). The data was being written *twice*.

The real bug: noise on the write line made one pulse look like two. The loopback test couldn't catch it because writing twice to the same register still reads back correctly.

> "We lost several months chasing the wrong thing because we guessed at the failure instead of looking at it."

### The Engineer's Trap

Engineers like to think. Thinking is fun—it's why we became engineers. But:

> "There are more ways for something to be broken than even the most imaginative engineer can imagine."

Thinking is easier than looking. Looking requires hooks, scopes, analyzers, debug statements. But guessing usually doesn't find the bug.

### See the Failure

What you see is the *result* of the failure. The light didn't come on—but was it the switch or the bulb?

**The well pump story:** A motor sound every few hours. They called the neighbor who sold pumps. "It's the well pump!" He replaced it. The sound kept happening. The actual cause: an electric air compressor left on in the garage. Nobody had stood near the pump to listen.

**The janitor story:** A server crashed and restarted every night at the same time. Logs showed nothing. Engineers stayed late and watched. At 11 PM, the power went off. The janitor had unplugged it to vacuum.

### See the Details

Each look reveals more about what's failing. Keep looking until the failure has a limited number of possible causes.

**Video compression story:** Output was too blocky. Motion estimation uses motion vectors to save bits. Added debug output showing detected motion as colored boxes. Left-right motion had fewer boxes than up-down. Looked at search calculations—the search algorithm wasn't checking all horizontal positions. Fixed the simple search bug; picture quality improved.

### Instrument the System

**Build it in during design:**
- Debug logs with switchable verbosity
- Status messages with timestamps
- Test points on hardware
- Performance monitors

**Add it later when needed:**
- Scopes, analyzers, meters
- New debug statements
- VCRs to record video output

### The Heisenberg Problem

Your instrumentation affects the system. Debug output changes timing. Scope probes add capacitance. Opening a PC case changes temperature.

This is unavoidable. Just be aware of it. After adding instrumentation, make it fail again to prove you haven't hidden the bug.

### Guess Only to Focus the Search

Guessing is fine—to decide *where to look*. But confirm with observation before acting.

**Light bulb exception:** If a problem is very likely AND easy to fix, try the fix without detailed observation. New bulb is cheap; golf lesson is cheaper than new clubs.

### ⚠️ Taking It Too Far

"Quit Thinking" doesn't mean abandon all reasoning. You still need hypotheses to decide *where* to instrument. The rule targets:
- Guessing the cause without evidence
- Acting on theories before observing

It does NOT mean:
- Random instrumentation with no direction
- Refusing to use domain knowledge
- Adding debug output everywhere

Use your brain to focus the search; use your eyes to confirm.

---

## 6. Rule 4: Divide and Conquer

> "How often have I said that when you have eliminated the impossible, whatever remains, however improbable, must be the truth?" —Sherlock Holmes

**The story:** Hotel reservation Macs were slow connecting to the database. The technician found errors in both directions. He looked at signals at the breakout box—good going out, bad coming in. Then at the flat cable—good going in, bad going out. The problem was *between* those points: cold solder joints in the breakout box.

After fixing that, one terminal was still slow. Now errors were only going *out*. He traced the cable and found one wire wasn't even connected—wired to the wrong pin. Signals were coupling through adjacent wires well enough to *mostly* work.

### Successive Approximation

Guess a number from 1 to 100 in seven guesses. Each guess cuts the range in half. If there are 100 places a bug might be, find it in 7 tries, not 100.

### Know the Range

If the answer is 135 and you assume 1-100, you'll never find it. Start with the whole system as the range.

### Know Which Side You're On

Things start good upstream, become bad downstream. You're looking for the point where they change.

```
       Good data                    Bad data
          │                            │
Input ────┼──► [System] ──► [BUG] ────┼──► Output
          │                            │
      Upstream                     Downstream
```

### Inject Easy-to-Spot Patterns

Random data is hard to analyze. Use patterns:
- "00 55 AA FF" to see corruption
- Spinning color wheel to detect frame drops
- Simultaneous click + screen flash to check audio sync

### Start with the Bad

Don't verify everything that works. Start where it's broken and work upstream.

**Furnace example:** Furnace doesn't start. Don't trace fuel flow from tank to spray head. Start at the furnace, check power (good), check thermostat (good), check safety override (tripped). Found it in three checks instead of twelve.

### Fix the Bugs You Know About

Multiple bugs hide each other. When you find one, fix it immediately, then continue.

### Fix the Noise First

Certain bugs cause other bugs:
- Hardware: noisy signals, glitchy clocks, bad voltage levels
- Software: race conditions, uninitialized variables, reentrant code

Fix these first—the "other bugs" often disappear.

### ⚠️ Taking It Too Far

Binary search is powerful but not always appropriate:
- **Obvious bugs**: If you see `null pointer` in the stack trace, go there directly
- **Small search space**: Three functions? Just read them
- **High bisection cost**: If each test takes 30 minutes, think before bisecting

Divide and Conquer is for *large, opaque* search spaces. When the bug is visible or the space is small, direct investigation is faster.

---

## 7. Rule 5: Change One Thing at a Time

> "They say genius is an infinite capacity for taking pains." —Sherlock Holmes

**The story:** Audio sounded bad. An engineer guessed framing was missing and added it. Still sounded bad. A debugging whiz came in, found a buffer pointer error with test patterns, and fixed it. Still sounded bad. Then the engineer remembered—he never removed his framing "fix." Audio clobbered twice doesn't sound worse than clobbered once. Remove the non-fix; audio worked perfectly.

> "When it didn't fix the problem, he should have backed it out immediately."

### Use a Rifle, Not a Shotgun

Swapping multiple components tells you nothing about which was bad. Worse, you might break something that was fine.

If you think you need a shotgun, you can't see the target clearly. Get better instrumentation.

### Grab the Brass Bar

On nuclear subs, there's a brass bar in front of the reactor controls. When alarms go off, engineers are trained to grab it and hold on until they understand what's happening. Quick fixes confuse recovery systems and bury the original fault.

**Christmas party story:** A stereo stopped working because the speaker wire ran behind the fireplace logs. Someone lit the fire; insulation melted; fuse blew. Instead of checking the fuse, they swapped speaker wires—and blew the other fuse. Now neither speaker worked.

### Compare with a Good One

Two logs—one good, one bad—side by side. What's different?

Pin down as many variables as possible. Same machine, consecutive runs, same input. The only difference should be the bug.

### What Changed Since It Worked?

**Turntable story:** A record player sounded terrible after cartridge repair. The new cartridge was a different type (magnetic vs ceramic) requiring a different input. Solution: flip a switch on the back of the amplifier. 30 seconds.

When a design change breaks things, compare versions. Source control tells you exactly what changed.

---

## 8. Rule 6: Keep an Audit Trail

> "There is no branch of detective science so important and so neglected as the art of tracing footsteps." —Sherlock Holmes

**The story:** A video compression chip would suddenly drop from 30 fps to 2 fps. It wasn't time-based—sometimes immediate, sometimes after hours. The next day, no failures. The day after, failures again. Then: getting up from the chair triggered it. A plaid flannel shirt! The compressor couldn't handle the complex moving pattern.

The bug report sent to the vendor included: what made it fail (standing up in front of camera), what it took to recover (restart), and even a photocopy of the shirt pattern.

### Write It Down

- What you did
- What order you did it
- What happened as a result

**Floppy story:** Customer's disk worked once then failed. Support kept sending new disks. Finally got a live play-by-play: customer put disk away by sticking it to the filing cabinet *with a magnet*.

### Details Matter

"It's broken" is useless. Describe:
- The exact symptom
- How much/how long
- What the system was doing
- The sequence of events

**Shoeless story:** An engineer felt a shock from a power supply. No one else could feel it. They were all wearing shoes; he wasn't.

### Correlate

"It made a loud noise for four seconds starting at 14:05:23" lets you match symptoms to log entries.

Synchronize clocks between systems. Annotate logs with symptoms not in the logs.

**Fred's gut story:** Garbage characters correlated with Fred's shifts. Fred's gut pressed the keyboard when he reached for coffee.

---

## 9. Rule 7: Check the Plug

> "There is nothing more deceptive than an obvious fact." —Sherlock Holmes

**The story:** Cold showers. The hot water heater was "instantaneous"—heats water as you use it. The thermostat read 140°; the system seemed fine. Turns out, the oil furnace was set to 165° (previous owner's backup setting). At 190° (proper primary setting), the heat exchanger worked perfectly.

The assumption: there was a good heat source. The reality: barely adequate heat source, invisible because it was "overhead infrastructure."

### Question Everything

| Obvious Question | Why It Matters |
|------------------|----------------|
| Is it plugged in? | You kicked out the phone plug |
| Is it turned on? | Weed whacker has an on/off switch |
| Did it initialize? | Memory not initialized means random behavior |
| Is the right code running? | Old code cached; new code never loaded |
| Is the right driver installed? | Wrong graphics driver |

### Start at the Beginning

Did you:
- Hit the start button?
- Reset the chip?
- Program the registers?
- Push the primer three times?
- Set the choke?

### Test the Tool

**File read story:** A consultant's read benchmark was slower than write. Weeks of optimization. Problem: file type defaulted to text, causing newline conversion. Set to binary; problem gone.

**Oil gauge story:** Furnace quit. Gauge said 1/4 full. Technician banged the gauge with his flashlight—it snapped to zero. Stuck gauge.

Before trusting test results:
- Touch scope probes to known voltages
- Print a message whether the event occurs or not
- Check meter batteries

---

## 10. Rule 8: Get a Fresh View

> "Nothing clears up a case so much as stating it to another person." —Sherlock Holmes

**The story:** Car trouble—reverse gear blew the brake light fuse. Associate said instantly: "The dome light is pinching a wire against the frame. Open it, clear it, wrap with tape." Skeptical, but it took 30 seconds to try. Sure enough, pinched wire under the dome light.

### Three Reasons to Ask for Help

| Type | What It Provides |
|------|------------------|
| Fresh view | Breaks you out of your rut |
| Expertise | Knowledge you don't have time to learn |
| Experience | "That happens all the time" |

Sometimes just *explaining* the problem gives you the answer. Some companies have a mannequin for this—explain to the mannequin first.

### Report Symptoms, Not Theories

> "Don't drag a crowd into your rut."

Your theories aren't working—that's why you need help. If you tell the helper your theory, you poison their fresh perspective.

**Bad:** "I think the memory timing is marginal."
**Good:** "Data is corrupted intermittently. Here's the pattern."

The doctor wants to hear "my lower back hurts when I bend," not "I looked it up and I have dorsal cancer."

### Where to Get Help

- Coworkers (insight + familiarity)
- Vendors (expertise + experience with their product)
- Web forums and user groups (peer experience)
- Troubleshooting guides (collected experience)
- Books and magazines (general expertise)

### Don't Be Proud

Asking for help means you want the bug fixed. Experts screw up too—if your data contradicts their theory, investigate further.

### ⚠️ Taking It Too Far

Asking for help too early stunts your growth:
- You don't build pattern recognition
- You don't learn the system deeply
- You become dependent on others

**Guideline:** Struggle for at least 30 minutes before asking. Document what you tried. The struggle itself builds expertise—even when you eventually need help.

---

## 11. Rule 9: If You Didn't Fix It, It Ain't Fixed

> "It is stupidity rather than courage to refuse to recognize danger when it is close upon you." —Sherlock Holmes

**The story:** Car stalled climbing hills. In L.A., it restarted immediately. In West Virginia, blamed the gas station—added Drygas. Later, stalling at highway speed on flat roads. Mechanic said "electrical problem," replaced wires, charged $75. Stalled again. Finally, found bad ground connection. Even then, it wasn't fully fixed until the ground was properly routed away from heat.

### Verify the Fix

See the bug not happen. See it with your own eyes.

**Bad verification:**
- "It seems to be working better"
- "I ran it ten times"
- "The customer hasn't called back"

**Good verification:**
- Reproduce the exact failure conditions
- Observe that the failure no longer occurs
- Understand *why* the fix works

### Check That It's Really Fixed

| Trap | What Happens |
|------|--------------|
| Testing the wrong thing | Fixed code for case A, tested case B |
| Testing in wrong environment | Works on your machine, fails in production |
| Coincidence | It was intermittent; you got lucky |
| "Fixes" that hide | Changed timing, bug still there |

### Understand Why It Works

> "If you don't know why it works now, it probably doesn't."

Don't accept magic. If you can't explain the fix, you haven't found the real bug.

**Caution:** Fixing one thing might expose another. Don't assume the new failure is the same bug.

### See It Happen, Then Not Happen

The best proof:
1. Make the bug happen with the old code
2. Apply the fix
3. Run the exact same test
4. See the bug not happen
5. Remove the fix
6. See the bug happen again

---

## 12. All Rules Together

Real debugging uses multiple rules simultaneously:

**Hotel reservation story (revisited):**
1. **Understand the System**: Knew DB-terminal communication used serial lines with error retry
2. **Make It Fail**: "Are you there?" messages provided constant signals to observe
3. **Quit Thinking and Look**: Used scope to see actual signals
4. **Divide and Conquer**: Tested halfway points to narrow to breakout box
5. **Keep an Audit Trail**: Tracked which terminals, which tests
6. **Check the Plug**: After fixing box, still one slow terminal—new problem, different cause
7. **If You Didn't Fix It**: Verified each terminal worked before moving on

---

## 13. Quick Reference

### The Nine Rules (Card Size)

```
1. UNDERSTAND THE SYSTEM
2. MAKE IT FAIL
3. QUIT THINKING AND LOOK
4. DIVIDE AND CONQUER
5. CHANGE ONE THING AT A TIME
6. KEEP AN AUDIT TRAIL
7. CHECK THE PLUG
8. GET A FRESH VIEW
9. IF YOU DIDN'T FIX IT, IT AIN'T FIXED
```

### Decision Tree

```
Bug reported
    │
    ├─► Can you reproduce it?
    │       NO → Rule 2: Make It Fail
    │       YES ↓
    │
    ├─► Can you see the actual failure?
    │       NO → Rule 3: Quit Thinking and Look
    │       YES ↓
    │
    ├─► Do you know where to look?
    │       NO → Rule 4: Divide and Conquer
    │       YES ↓
    │
    ├─► Are you stuck?
    │       YES → Rule 8: Get a Fresh View
    │       NO ↓
    │
    ├─► Did you check assumptions?
    │       NO → Rule 7: Check the Plug
    │       YES ↓
    │
    ├─► Did you write it down?
    │       NO → Rule 6: Keep an Audit Trail
    │       YES ↓
    │
    ├─► Apply fix, test one variable
    │       Rule 5: Change One Thing at a Time
    │       ↓
    │
    └─► Verify fix works
            Rule 9: If You Didn't Fix It, It Ain't Fixed
```

### Common Traps

| Trap | Violated Rule |
|------|---------------|
| Guessing without looking | Rule 3 |
| Fixing without reproducing | Rule 2 |
| Changing multiple things | Rule 5 |
| Not writing down what happened | Rule 6 |
| Assuming the obvious | Rule 7 |
| Testing on different config | Rule 9 |

---

## 14. Connection to Khorikov (Testing)

| Agans (Debugging) | Khorikov (Unit Testing) |
|-------------------|------------------------|
| Make It Fail | Tests reproduce failure conditions |
| Divide and Conquer | Tests isolate units |
| Change One Thing | Tests control variables |
| Quit Thinking and Look | Tests provide observable output |

**Shared insight:** Good tests are debugging tools. A failing test tells you *exactly* what failed and narrows the search space.

Both emphasize: observable behavior over guessing, isolation over integration, reproducibility over intermittence.

---

## 15. Connection to Ousterhout (Design)

| Agans (Debugging) | Ousterhout (Design) |
|-------------------|---------------------|
| Understand the System | Deep modules hide complexity |
| Divide and Conquer | Interfaces isolate modules |
| Build instrumentation in | Design for debuggability |
| Check the Plug | Know your abstractions' guarantees |

**Shared insight:** Good design makes debugging easier. Deep modules with simple interfaces create natural divide-and-conquer points.

Ousterhout's "design it twice" principle: if you don't understand the system, you can't debug it. Understanding comes from good design.

---

## 16. Connection to Beck (Extreme Programming)

| Agans (Debugging) | Beck (XP) |
|-------------------|-----------|
| Make It Fail | Test-first: write failing test before fix |
| Change One Thing at a Time | Small releases, incremental change |
| Keep an Audit Trail | Version control, continuous integration |
| Get a Fresh View | Pair programming |
| If You Didn't Fix It, It Ain't Fixed | Tests must pass before commit |

**Shared insight:** Debugging and development are the same discipline. XP practices are debugging practices applied proactively.

Beck's "test-first" is Agans' "Make It Fail" applied before writing code. Pair programming is "Get a Fresh View" built into the workflow. Both reject big-bang changes in favor of small, observable steps.

---

## 17. Key Quotes

> "When it took us a long time to find a bug, it was because we had neglected some essential, fundamental rule; once we applied the rule, we quickly found the problem."

> "Don't guess. Look it up."

> "You have enough bugs already; don't try to create new ones."

> "There are more ways for something to be broken than even the most imaginative engineer can imagine."

> "We lost several months chasing the wrong thing because we guessed at the failure instead of looking at it."

> "If you think you need a shotgun to hit the target, the problem is that you can't see the target clearly."

> "When it didn't fix the problem, he should have backed it out immediately."

> "The detail you ignore will be the one that matters."

> "Report symptoms, not theories."

> "If you don't know why it works now, it probably doesn't."

> "It is a capital mistake to theorize before one has data." —Sherlock Holmes

> "Nothing clears up a case so much as stating it to another person." —Sherlock Holmes

---

*Based on Agans, David J. "Debugging: The 9 Indispensable Rules for Finding Even the Most Elusive Software and Hardware Problems." AMACOM, 2002. ISBN 978-0814474570.*
