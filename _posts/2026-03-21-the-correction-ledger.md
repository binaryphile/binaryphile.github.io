---
layout: post
title:  "The Correction Ledger: Structured Error Correction in AI-Assisted Engineering"
date:   2026-03-21 12:00:00 +0000
categories: development ai collaboration
---

An external reviewer told us not to instrument every pipeline stage. Over-engineering, they said. We had seven stages in a streaming pipeline, and the reviewer had been right about everything else that session -- catching vocabulary imprecision, forcing our numbers to reconcile, flagging overclaims we hadn't noticed.

I pushed back. We instrumented everything anyway. The constraint was visible in the first 2-second stats interval. Store idle 94% of the time. HNSW idle 99%. Embed at capacity. Six stages that looked like they could be improved were irrelevant. If we'd taken the reviewer's advice on that one call, we'd still be debugging the wrong bottleneck.

The reviewer was wrong about what to build but right about dozens of other things over the following weeks. That pattern -- each reviewer wrong about different things, and a record of who caught what -- changed how I think about AI-assisted engineering.

The [companion post](/development/go/toc/2026/03/21/toc-in-a-go-pipeline/) tells what we built: a Go code indexer pipeline, instrumented with Goldratt's Theory of Constraints as a design lens, that went from OOM-killing on every run to completing reliably. This post tells what the collaboration process revealed.

## The Method

The [G/I cycle post](/development/2026/02/02/the-g-i-cycle-iterative-refinement-with-ai-assistants/) describes the review methodology in detail. This post adds the correction ledger -- a simple record of what was wrong, who caught it, and why -- and an error taxonomy that emerged from keeping it.

The setup: Claude Code for drafting and implementation. ChatGPT as adversarial reviewer, invoked via a `/g` slash command that copies work to the clipboard for external grading. Me as integrator -- deciding which corrections to accept, resolving contradictions, owning final truth claims.

The protocol in practice: complete a piece of work (code change, blog draft, design plan), invoke `/g`, paste into ChatGPT with a prompt like:

> Grade the following adversarially at staff level. Challenge assumptions, find blind spots, and identify anything a senior engineer would flag in code review.

The reviewer grades on a D-to-A+ scale with specific deductions. Each grade comes with a concrete list of what would raise it. I decide what to fix and what to override. After fixes, run `/g` again. Stop when corrections stop being structural.

Two Claude Code instances worked on separate codebases (the indexer and its pipeline library) in different repositories, coordinating through event streams rather than shared context. That's operational separation -- different repos, different project instructions -- not a deliberate design for cognitive diversity. The library-application feedback loop is covered in the companion post; this post focuses on the review protocol.

Over 18 days: 15+ commits, 10+ adversarial code reviews, 6 adversarial blog post reviews. Full tool transparency: Claude Code (Anthropic) for implementation, ChatGPT (OpenAI) for adversarial grading, era event streams for cross-agent coordination.

## What the Ledger Showed

I started keeping a correction ledger partway through the project -- recording what was wrong, who caught it, and why the catcher could see what the maker could not. The ledger wasn't planned as a research artifact; it emerged because the same patterns kept appearing.

To be clear: this ledger was reconstructed after the fact from session transcripts, inbox streams, and stored memories -- not maintained contemporaneously. Each entry records the claim under review, the objection raised, who surfaced it, the evidence requested or produced, and the disposition (accepted, rejected with reasoning, or deferred). It's a retrospective analysis tool, not a real-time log. Its value is pattern recognition, not bookkeeping.

Four error classes showed up repeatedly.

### Conceptual errors

The adversarial reviewer caught the practitioner being sloppy with source material.

We framed memory as "a second constraint dimension" -- an extension to the TOC model for handling memory pressure alongside throughput. It sounded sophisticated. We'd written code around it, discussed it at length, built it into the pipeline architecture. The reviewer pointed out it was wrong: the constraint simply moved after we elevated embed throughput. That's standard Step 5 in Goldratt's process -- "Do not allow inertia to cause a system's constraint."

The precision fix from the reviewer's notes captured it exactly:

| Sloppy | Precise |
|---|---|
| "memory is THE constraint" | "after CPU was elevated, safe resident memory became the active system constraint" |
| "the model works as-is" | "the TOC model did not need extension; our implementation needed to catch up with it" |

Claude and I both had implementation investment in the "two dimensions" framing. The reviewer had no such investment and could see the model didn't need extending. This is the core dynamic of conceptual errors: the builder's design commitment prevents them from questioning their own framing.

Similarly, we wrote "buffer prevents starvation." Wrong -- the buffer protects constraint utilization from upstream variability. The distinction matters: starvation is about the constraint having nothing to process; utilization protection is about the constraint losing time it can never recover. We were practitioners paraphrasing theory from memory; the reviewer held us to the source.

### Quantitative errors

The reviewer forced the numbers to reconcile when the narrative wanted to move on.

The embed stage reported `svc=7h39m` cumulative service time with 60 minutes wall time and one effective worker. Claude had built a narrative around "99.99% utilized" and I'd accepted it without checking. The reviewer caught it immediately: "If embed has one worker, cumulative service time for that stage should be roughly bounded by wall time, not 7.65x wall time."

The metric was contaminated -- eight worker goroutines blocked on a memory semaphore, all counted as "busy" by the instrumentation. The 7.65x ratio was seven workers doing nothing but waiting for permission. We'd built a utilization claim on a metric that included queue time. The reviewer's math caught what our understanding of our own instrumentation missed.

The Chromebook sizing table said E=2 for 5.5GB available memory. The formula, applied with the same constants shown in the code block above it, gives E=1. Claude trusted the table without checking the math. I trusted Claude. The reviewer ran the numbers.

But the most telling example deserves its own space. We reported a 5.4GB RSS spike during streaming with ~2.4GB unattributed. Claude wrote "likely from Go runtime page release behavior during a large batch." The reviewer refused to accept it:

> That explanation is weak. Page release generally reduces RSS, not spikes it. "During a large batch" is also speculative unless you correlated it with batch size, GC trace, allocator activity, or a stage transition.

That refusal forced three diagnostic runs. First, `GODEBUG=gctrace=1` -- which showed a correlated Go heap burst from 550MB to 1.3GB but couldn't explain the full 3.1GB RSS increase. Second, the memSampler -- which separated Go-managed physical memory from native memory and showed native stayed flat at 1.8GB. The entire delta was Go-managed. Third, a heap profile captured during the spike -- which identified the dominant allocator family: go-git packfile decode in the commit pipeline. `MemoryObject.Write` (97MB), `idxfile.genOffsetHash` (80MB), `readObjectNames` (52MB). The commit pipeline was materializing git objects from packfiles into memory -- the same heap pressure we'd already fixed in the code pipeline by switching to filesystem reads.

The reviewer didn't know what the answer was. They knew the accounting didn't close, and they wouldn't let it go. That single insistence -- "your numbers don't add up, show me" -- was the highest-value behavior in the entire collaboration. It produced a root cause we wouldn't have found otherwise, and it generated a fix (replace go-git commit iteration with `git log` subprocess) that we'd never have prioritized without the evidence.

### Context errors

The reviewer lacked engineering context that the human had.

"Don't instrument every stage" was wrong. Instrumentation was the prerequisite for constraint identification -- the entire point of Step 1 in Goldratt's process. If you can't see a phase's utilization and idle time, you can't determine whether it's the bottleneck. I overrode based on engineering judgment: the reviewer was optimizing for simplicity, but observability was the prerequisite, not a luxury. This became a working principle: instrumentation is the goal, not a means to a performance end. First we understand, then we seek to change.

Claude wrote "we spent weeks optimizing the wrong constraint." I corrected this: the throughput work was valuable. We improved worktree walk, added PathFilter, implemented batch embedding, switched to ORT. Those were correct improvements to a real bottleneck. The OOM was a different constraint entirely -- hidden behind the speed problem because we killed test runs before they reached the phase where memory spiked. Calling the throughput work "wrong" was dramatic but inaccurate. I knew the history. The reviewer didn't.

These context errors reveal a real limitation of text-based adversarial review: the reviewer sees the artifact, not the journey. They can check internal consistency and formal precision, but they can't evaluate whether a decision was reasonable given what was known at the time.

### Structural/design errors

The reviewer saw structural problems the builder missed because of proximity.

The fluentfp library agent designed a Merge+Collector composition for branch recombination after a fan-out. The pipeline needed to broadcast one input to two parallel branches (extract docs, extract call graph), then recombine the results. Merge interleaved the two branch outputs into a single stream; Collector accumulated N items and folded them.

An external reviewer graded this C and pointed out the semantics were wrong. Merge destroys provenance -- you can't tell which branch produced which item. Collector's windowed fold doesn't guarantee one-from-each-branch. If one branch errors and the other succeeds, the fold gets a partial result and the behavior depends on arrival order. Same upstream outcome, different downstream outputs depending on which goroutine sends first. That's a semantic smell.

The builder had verified that each operator worked individually. The reviewer saw that the *composition* was wrong -- a topology error that unit tests of individual operators would never catch. We killed both operators and replaced them with a purpose-built Join that waits for exactly one result from each of two typed input channels, combining Ok/Ok pairs and short-circuiting on errors.

### The pattern

In this workflow, conceptual and quantitative errors were consistently caught by the adversarial reviewer. Context errors were caught by the human. Structural errors required a reviewer with distance from the code.

No single participant caught all classes. That is the structural argument for independent adversarial review: not that any one reviewer is better, but that different reviewers tend to be wrong about different things. Disagreement was a trigger for investigation, not evidence of correctness -- the arbiter used local knowledge, instrumentation, and source fidelity to decide.

## The Blog Post Itself

The companion post went through six adversarial review rounds:

| Round | Structural issue surfaced | Evidence added |
|-------|---------------------------|----------------|
| 1 | TOC vocabulary overclaiming, no causal chain for OOM | -- |
| 2 | "Second dimension" wrong, causal gap between HNSW finalize and embed concurrency | Explicit phase timeline |
| 3 | Chromebook math contradiction, ORT memory persistence unexplained | Number reconciliation, allocator retention explanation |
| 4 | svc metric contaminated by semaphore wait, two OOM modes conflated | Metric caveat, failure mode separation |
| 5 | Spike memory accounting gap (~2.4GB unattributed) | gctrace + memSampler diagnostic runs |
| 6 | Go heap burst identified but not attributed to subsystem | pprof heap profile: go-git packfile decode |

Each round invalidated something the previous round had accepted. The post you're reading also went through the same process. The `/g` cycle works on prose, not just code -- because prose makes falsifiable claims under incomplete context, same as code.

## Where the Loop Failed and What It Cost

The protocol is not infallible.

The adversarial reviewer's advice to skip instrumentation could have cost us weeks if followed. Adversarial review is not the same as correct review. The reviewer brings rigor and fresh eyes, but the engineer brings context about what is prerequisite versus what is premature. When those conflict, the engineer must be willing to override -- and must be right.

Claude self-grades leniently. An A from self-assessment is typically a B from external review. This was consistent enough across the project to be a rule: never trust the drafter's self-assessment. The `/g` external check is mandatory, not optional.

The embed instrumentation boundary problem -- semaphore wait counted as service time, making utilization metrics meaningless for that stage -- survived multiple review rounds before being caught. Errors that require understanding the runtime behavior of concurrent code are harder for text-based reviewers to detect than errors in logic or arithmetic. The reviewer can check "do these numbers add up?" but not "is this metric measuring what you think it's measuring?"

Errors of omission are harder to catch than errors of commission. No reviewer asked "why not subprocess isolation for ORT?" until late in the process, despite it being an obvious architectural alternative that would have cleanly separated native memory from Go heap.

### What it cost

18 days wall clock, roughly 2-3 hours per day of human attention when active. 10+ adversarial code reviews, 6 adversarial blog post reviews. Each `/g` round costs about 5 minutes of human attention: copy the work, paste into the reviewer, read the response, decide what to fix. The corrections it surfaces would take hours to find through testing or customer feedback. The ratio is asymmetric in the right direction.

Token cost was substantial but not tracked precisely -- a gap I'd close next time.

### What this cannot prove

This was a single project with a single expert operator. A less experienced engineer might get different value from the same protocol -- or might not have the judgment to override bad reviewer advice. The reviewers were not independent in the strong sense: the same human framed the prompts, selected what to review, and curated the artifacts. Attribution in the ledger is inherently subjective -- the person who ran the workflow also assigned credit.

This says more about this review protocol than about the specific models. A different model pair might produce similar results if the protocol is the same. We have no controlled baseline: we don't know what a single-model workflow would have caught or missed.

## What's Transferable

A lightweight protocol any engineer can adopt:

**Separate drafting from review.** Don't ask the same model that wrote the code to review it. The drafter has narrative momentum and design investment that prevents it from seeing its own errors. A different model -- or the same model in a fresh context -- doesn't share those commitments. This is the single highest-leverage change.

**Use adversarial framing.** "Grade this adversarially at staff level" produces different output than "review this code." The framing matters. Polite review finds surface issues. Adversarial review finds structural ones.

**Keep a correction ledger.** Record what was wrong, who caught it, and why the catcher could see what the maker could not. The ledger is the artifact that makes the process auditable and the patterns visible. Without it, corrections are noise. With it, they're data.

**Human as integrator, not tiebreaker.** The human decides which corrections to accept, resolves contradictions between reviewers, and owns final truth claims. This is not a vote. It's synthesis. The human brings context that no reviewer has: project history, user needs, engineering taste, and the willingness to override a confident-sounding recommendation when the engineering judgment says otherwise.

**Stop when corrections stop being structural.** When the reviewer is suggesting word-level changes instead of finding conceptual errors, you're past the point of diminishing returns. Ship it.

**When this is overkill.** Use the full protocol when the problem is ambiguous, evidence is incomplete, incorrect claims are costly, or architecture and performance behavior are involved. Don't use it for local low-risk changes where correctness is mechanically verifiable -- the review overhead exceeds the consequence of being wrong.

---

In this project, the more durable gain from AI assistance wasn't drafting speed. It was that structured error correction produced a better result than any single participant would have reached alone.

The useful unit wasn't the model output. It was the correction protocol: independent review, explicit attribution, and a human making the final synthesis.

Build the loop. Keep the ledger.

---

*The indexer is [era](https://codeberg.org/binaryphile/era). The pipeline library is [fluentfp/toc](https://github.com/binaryphile/fluentfp). The review protocol is described in [The G/I Cycle](/development/2026/02/02/the-g-i-cycle-iterative-refinement-with-ai-assistants/). The technical case study is [Constraint-Based Indexing](/development/go/toc/2026/03/21/toc-in-a-go-pipeline/).*
