---
layout: post
title: "Epistemic Rigor in Engineering Decisions"
category: development
tags: [methodology, decision-making, engineering-culture]
---

# Epistemic Rigor in Engineering Decisions

Most engineering mistakes aren't technical. They're epistemic. Someone treated an assumption as a fact, skipped a validation because the reasoning "made sense," or cited documentation as proof of runtime behavior.

The cost isn't always dramatic. Usually it's a migration that takes twice as long because nobody tested the one assumption that mattered. A spike that produces false confidence. A plan built on a chain of inferences that each seemed reasonable but collectively amounted to a guess.

Epistemic rigor means knowing what you're standing on. Not every claim needs the same evidence. But you need to know the difference between "I observed this" and "I reasoned this should be true" — because those require different actions.

## Five levels of confidence

Each level earns its place because it dictates a different action. If two levels produce the same "what do I do next," they should be one level.

| Status | Meaning | Action |
|--------|---------|--------|
| **Verified** | Directly observed — ran the command, read the file, inspected the output | None. Act on it. |
| **Documented** | Found in an authoritative source but not independently tested | Verify the behavior before trusting it at runtime. Docs can be wrong or stale. |
| **Analysis** | Reasoned from verified facts but not empirically tested | Validate the reasoning. Look for logical gaps. The premises may be true but the conclusion may not follow. |
| **Inferred** | Plausible interpretation of indirect evidence | Design a targeted test. You have a hypothesis — validate or refute it. |
| **Unverified** | Unknown | Exploratory testing. You don't have a hypothesis yet, so you need to discover what's true. |

The difference between *Inferred* and *Unverified* matters more than it looks. "fetch() should work in Node.js runtime, so the proxy pattern should survive" is inferred — you have a hypothesis, and you can test the proxy endpoint directly. "Does Turbopack work with our codebase?" is unverified — you have no hypothesis, you just need to run it and see what happens. Hypothesis-driven testing and exploratory testing allocate time differently and have different definitions of "done."

## Where this breaks down in practice

### Documentation treated as verification

"The Next.js docs say middleware runs in edge runtime" is documented, not verified. When the docs are the basis for an architectural decision that affects production, you need to verify the behavior, not just read about it.

Bad: "Next.js docs say middleware should be used for request interception, not proxying — this confirms our bug."

The docs describe *intent*, not *cause*. What you observed (a crash) and what the docs recommend (a different pattern) are independent facts. Don't let one confirm the other.

### Cascading inference

If your conclusion depends on multiple unverified assumptions chained together, you're building on sand. Each inference in the chain is reasonable on its own. Together they compound uncertainty.

"fetch() works in Node.js" (verified) + "the proxy uses fetch()" (verified) + "so the proxy should work after the runtime change" (analysis) is one level of reasoning from verified facts. That's fine — validate the logic.

"The proxy should work" (analysis) + "so auth should work through the proxy" (inference from analysis) + "so the migration won't break login" (inference from inference) is a chain. By the third link, you're not reasoning from facts anymore. Stop and test.

### Clean narratives that fabricate details

When you write a report or summary, you'll find yourself inserting details that make the story cleaner — round numbers, extra attempts that didn't happen, dramatic contrasts. These aren't lies. They're the narrative filling gaps with plausible fiction. After writing, check every specific claim (numbers, timelines, what was tried) against the record.

### "Should work" as a verdict

An untested claim that "should work" is not a positive finding. It's an unverified claim wearing a green hat. If you can't fully test something, say so. Note what would be needed to raise your confidence. Don't default to optimism.

## When to invest in verification

Not everything needs full verification. The question is: what's the cost of being wrong?

A claim that drives a decision — how many story points, whether to proceed with a migration, which architecture to use — is high-stakes. Verify it at source level: run the command, read the file, inspect the output.

A claim that provides context — background on why a tool exists, general industry trends — is low-stakes. Citing a source is sufficient.

The test: "If this claim is wrong, does the conclusion change?" If yes, verify.

## Making it practical

For plans and spike documents, list your key assumptions and mark them. A simple table works:

```
Key Assumptions (unverified — spike must validate)
- next-auth v4 runtime compat with Next.js 16
- proxy.ts default export works in Node.js runtime
- requestTimeout patch applies to 16.x
```

This makes the plan's purpose visible: converting unverified claims into verified ones. The spike isn't "try the upgrade." The spike is "answer these specific questions."

For reports and architecture documents, tag claims inline where they appear in prose. "MIPS32 support is *unverified* — no prebuilt binaries exist, cross-compilation not attempted." The reader sees the tag and knows not to build on that claim without further work.

The taxonomy doesn't need to be rigid. What matters is the habit: before you act on a claim, know what kind of claim it is and what that means for your next step.
