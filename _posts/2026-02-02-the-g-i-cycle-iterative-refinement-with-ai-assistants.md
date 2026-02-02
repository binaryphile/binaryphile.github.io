---
layout: post
title:  "The G/I Cycle: How Specific Deductions Beat 'Try Harder'"
date:   2026-02-02 00:00:00 +0000
categories: development
---

You write something with AI. It's 70% right. Now what?

Most people accept it. That leaves quality on the table — wins that need only a little effort to tease out, but are typically much more expensive to defer to implementation.

The G/I cycle fixes this.

## The G/I Cycle

G/I stands for Grade/Improve. The cycle is simple:

```
Work → Grade → Improve → Re-grade → Repeat until stuck
```

**Grade** means assigning a letter grade with specific point deductions. Not "this is pretty good" — that tells you nothing. Instead: "B+ (86/100). Deductions: -5 for not checking X, -4 for missing baseline, -3 for unverified assumption."

**Improve** means addressing those deductions. Each "-5 for X" becomes a task. Do the task, then grade again.

**Repeat** until you can't identify concrete improvements, or remaining deductions total less than 5 points.

**The test:** "If asked to improve right now, what would I do?" If you have an answer, you're not done.

## Why It Works

Three mechanisms:

**1. Provides attention bandwidth.** Each iteration lets the model focus on concerns it couldn't address earlier. It genuinely improves itself across passes. These are free wins — you just say "improve" and the LLM follows its own judgment based on its grade. Most G/I cycles are just this: low-effort extraction of quality the model already knows how to deliver.

**2. Exposes thinking for course correction.** Grading externalizes the model's assessment. You can see what it thinks is wrong. Most of the time, you let it run. But occasionally you notice something off — a wrong assumption, a misguided priority. That's when you redirect. A single course correction can prevent entire avenues of wasted inquiry.

**3. Surfaces unknown unknowns.** Grading forces the model to ask "what didn't I check?" — questions it wouldn't ask if just told to "improve." For deeper blind spots, use "grade your analysis" to grade at a meta level: the thinking process, not just the output.

**A note on self-grading:** LLMs grade themselves leniently. If you find gaps after an A, the A was wrong. B is not "acceptable" — B is incomplete work. Push past it.

## The Economics

**Stand on the LLM's shoulders, not vice versa.**

Your attention is expensive. The LLM's iterations are cheap. Let it do its best work first — then invest your attention in evaluating the result.

Wrong: You guide every step → LLM executes → you fix gaps
Right: LLM iterates to its best → you evaluate final output → you build on that foundation

**When to step in:** Remaining deductions under 5 points, grade stabilizes across iterations, or gaps require information you have and it doesn't. Don't stop just because you "improved once" or it "feels complete." Use the point threshold.

## One Caveat

Self-run G/I cycles in a single response aren't worthwhile — except that they expose thinking for course correction. The value is in the separate prompts: you see the thinking, you can redirect if needed, then you say "improve." Ignore the grade itself — focus on the deductions. If there are actionable deductions you find valuable, it's not done, even if it gave itself an A+. It wanted to be done, but shouldn't be. For deeper blind spots, say "grade your analysis" to surface unknown unknowns.

## When G/I Works

Structured content, documentation, analysis, code review prep.

Why: These domains have verifiable criteria. You can objectively assess completeness, accuracy, and coverage. The grade has meaning.

## When G/I Doesn't Work

- **Creative work** — no objective grading standard
- **Unstable requirements** — criteria change faster than iterations
- **Time pressure under 5 minutes** — overhead exceeds benefit

## Getting Started

Try it on your next draft:

1. Ask the AI: "grade the plan" when planning or "grade your work" after implementation
2. Glance at the deductions — redirect only if something looks off
3. Ask it, "improve" (nothing specific)
4. Repeat until deductions total less than 5 points
5. Now invest your attention in the result

Most cycles, step 2 is just a glance — you barely have to look. The AI follows its own judgment, and that's usually fine. Just say "improve" (or configure a shortcut like `/i`). The value is in the accumulated improvement across iterations, plus the occasional checkpoint where you catch something before it goes sideways.

## Example: Catching a Fabrication

A coaching report claimed "Research supports iteration for exploration and idea generation" — citing "Zhang et al. (2024)."

Grading would have caught:
- **-10:** Citation mismatch — actual source says TDD remediation for local errors, not "exploration"
- **-5:** Phantom citation — "Zhang et al. (2024)" doesn't exist

Without G/I, the claim survived to the final report as unsourced "common wisdom." With G/I, it would have been flagged and fixed in iteration 1.

## The Payoff

The G/I cycle lets you extract the LLM's best work before investing your attention. You stand on its shoulders rather than having it stand on yours.

The resulting plan stands alone — the synthesis baked in the dependencies. That's how you free attention for implementation: you're not carrying unresolved planning concerns forward.

## The Reference

Copy this into your LLM's system prompt or project instructions:

```markdown
# G/I Cycle Reference

## The Cycle

Work → Grade → Improve → Re-grade → Repeat until stuck

**Grade:** Assign a letter grade with specific point deductions.
**Improve:** Address the deductions (or just say "improve" and let the LLM follow its judgment).
**Repeat:** Until remaining deductions <5 points or you hit a wall.

## Why It Works (Practical)

### 1. Attention Bandwidth (Primary Benefit)

Each iteration lets the model focus on concerns it couldn't address earlier. Most G/I cycles are just this: low-effort wins you'd otherwise defer to implementation.

### 2. Course Correction (Occasional)

Grading externalizes the model's thinking. Most of the time, you let it run. Occasionally you notice something off and redirect. A single course correction can prevent entire avenues of wasted inquiry.

### 3. Surfaces Unknown Unknowns

Grading forces the model to ask "what didn't I check?" — questions it wouldn't ask if just told to "improve." For deeper blind spots, use "grade your analysis" to grade at a meta level.

## Why Complexity Requires G/I (Theory)

One theory that aligns with observed results: LLMs have limited coherent attention for evaluating plans. Single-shot has enough budget for trivial changes but not complex ones. G/I works around this limit through:

1. **Output extends thinking** — writing the grade surfaces concerns that wouldn't fit in the attention window otherwise
2. **Synthesis reduces dependencies** — evaluation collapses conceptual complexity (like substituting y for f(x) — the evaluation happens once, not repeatedly)
3. **Addressed concerns free capacity** — each iteration doesn't re-attend to what's already fixed
4. **Surfaces what the LLM doesn't know it doesn't know** — LLMs have blind spots they can't see. Grading at a meta level (grading the thinking process, not just the output) can knock these loose

**The phasing effect:** G/I shifts planning work to the planning phase, where it belongs. Without G/I, unresolved planning concerns bleed into implementation, competing for attention and context needed for implementation details.

**Self-contained plans:** Planning evaluation produces a plan that stands alone — it no longer requires the context of the dependencies you evaluated to create it. The synthesis baked them in.

This reframes the economics: it's not just that fixing things later costs more effort. Unresolved planning work *actively degrades* implementation by consuming resources needed for implementation details.

## Grading Format

**Weak:** "I did a good job but could have done better."

**Strong:** "B+ (86/100). Deductions: -5 for not checking X, -4 for no baseline, -3 for unverified assumption."

## Watch for Inflated Grades

LLMs grade themselves leniently. If you find gaps after an A, the A was wrong. B is not "acceptable" — B is incomplete work. Push past it.

If you're getting As but the deductions feel real, they are real. Address them.

## The Test

> "If asked to improve right now, what would I do?"

If you have an answer, you're not done.

## When to Stop (Valid)

| Condition | Action |
|-----------|--------|
| Remaining deductions <5 points | Stop — diminishing returns |
| Gaps require unavailable data | Stop — document as limitation |
| Next iteration would repeat searches | Stop — exhausted the approach |
| Grade stabilizes across 2 iterations | Stop — no new gaps surfacing |

## When NOT to Stop (Invalid)

- "I improved once already" — one iteration is minimum, not maximum
- "Feels complete" — subjective; use point threshold
- "This is taking too long" — time estimates unreliable
- "User hasn't complained" — user doesn't know what you didn't check

## Economics

**Stand on the LLM's shoulders, not vice versa.**

LLM iterations are cheap. Your attention is expensive. Let the LLM do its best work first — then invest your attention.

**When to step in:** Remaining deductions <5 points, grade stabilizes, or gaps require data you have and it doesn't.

## Observed Limitation

Self-run G/I cycles in a single response aren't worthwhile — except that they expose thinking for course correction. The value is in the separate prompts: you see the thinking, you can redirect if needed, then you say "improve." Ignore the grade — focus on the deductions. If there are actionable deductions you find valuable, it's not done, even with an A+. It wanted to be done, but shouldn't be. For deeper blind spots, "grade your analysis" can surface unknown unknowns.

## When G/I Works

- Structured content
- Documentation
- Analysis
- Code review prep

Why: Verifiable criteria exist. You can objectively assess completeness, accuracy, coverage.

## When G/I Doesn't Work

- **Creative work** — no objective grading standard
- **Unstable requirements** — criteria change faster than iterations
- **Time pressure <5 minutes** — overhead exceeds benefit

## Quick Start

1. "Grade the plan" (when planning) or "Grade your work" (after implementation)
2. Glance at deductions — redirect only if something looks off
3. "Improve" (nothing specific)
4. Repeat until <5 points remaining
5. Invest your attention in the final result
```
