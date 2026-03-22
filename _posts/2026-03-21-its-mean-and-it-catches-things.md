---
layout: post
title:  "It's Mean and It Catches Things"
date:   2026-03-21 12:00:00 +0000
categories: development ai collaboration
---

ChatGPT told me not to instrument every pipeline stage. Over-engineering, it said.

It had been right often enough that the advice carried weight — especially on vocabulary, reconciled numbers, and overclaims.

I instrumented everything anyway. The bottleneck was visible in the first 2-second stats interval. Store idle 94%. HNSW idle 99%. Embed at capacity.

Eighteen days of building [era](https://codeberg.org/binaryphile/era) with Claude Code drafting and ChatGPT grading. ChatGPT caught certain kinds of mistakes. I caught others. Neither caught everything.

I didn't notice this as a pattern while building. Later I went back through session transcripts to check whether I was remembering selectively. Looking back through one project, four failure modes kept recurring. The examples are real. The pattern changed how I work.

This is not a clean model-vs-model comparison. Claude Code had long-running implementation context and momentum. ChatGPT got fresh-context adversarial prompts and no sunk cost. Some of what I'm describing is probably role separation and task framing, not model identity.

*Companion post: [Zero Goodput](/development/go/toc/2026/03/21/zero-goodput/).*

## The setup

Claude Code and I work inside a structured checkpoint protocol I built called [tandem](https://codeberg.org/binaryphile/tandem-protocol). Implementation and review follow a plan-gate-implement-gate cycle. When I want adversarial review, I copy the current work to ChatGPT with a staff-level grading prompt. ChatGPT returns a letter grade with specific deductions. I paste the grade back into Claude Code, which reads the findings and fixes them. The [G/I cycle post](/development/2026/02/02/the-g-i-cycle-iterative-refinement-with-ai-assistants/) describes the methodology.

When I say "ChatGPT caught X," I mean this configuration: adversarial prompt, staff-level framing, fresh context each time.

## Conceptual errors

ChatGPT caught me paraphrasing a framework I should have been applying.

I framed memory pressure as "a second constraint dimension" — my own extension to Goldratt's Theory of Constraints. ChatGPT flagged it. The constraint simply moved after I elevated embed throughput. Standard Step 5. The model didn't need extending. My implementation needed to catch up with it.

| Sloppy | Precise |
|---|---|
| "memory is THE constraint" | "after CPU was elevated, safe resident memory became the active system constraint" |
| "the model works as-is" | "the TOC model did not need extension; our implementation needed to catch up with it" |

Claude Code and I had built the pipeline's memory handling around the "two dimensions" idea for two weeks. ChatGPT hadn't.

## Quantitative errors

ChatGPT forced the numbers to reconcile when Claude Code and I wanted to move on.

The embed stage reported `svc=7h39m` cumulative service time on a 60-minute run with one effective worker. Claude Code built a narrative around "99.99% utilized." I didn't think to question it. ChatGPT caught it: one effective worker means service time should be roughly bounded by wall time. Not 7.65x.

Eight worker goroutines blocked on a memory semaphore, all counted as "busy." Seven doing nothing but waiting for permission.

I reported a 5.4GB RSS spike with over 2GB unattributed. Claude Code wrote "likely from Go runtime page release behavior during a large batch." ChatGPT refused:

> That explanation is weak. Page release generally reduces RSS, not spikes it. "During a large batch" is also speculative unless you correlated it with batch size, GC trace, allocator activity, or a stage transition.

Three diagnostic runs followed. GC tracing, a memory sampler, a heap profile. Each ruled out one explanation. The heap profile identified the dominant allocator: go-git packfile decode in the commit pipeline. The [companion post](/development/go/toc/2026/03/21/toc-in-a-go-pipeline/) has the engineering detail.

ChatGPT didn't know the answer. It knew the accounting didn't close.

## Context errors

I caught what ChatGPT couldn't see.

"Don't instrument every stage" was wrong. Without instrumentation I'd have been guessing which stage to fix. ChatGPT hadn't seen the pipeline run.

Claude Code wrote "we spent weeks optimizing the wrong constraint." The throughput work made indexing faster. The OOM was something else entirely — hidden because I killed test runs before they reached the failing phase. I knew that. ChatGPT saw the text in front of it.

## Structural errors

ChatGPT saw composition problems I missed because I was too close.

Two branches had to produce results and come back together. Claude Code composed a Merge and a Collector to do it. Each passed its own tests. The composition was wrong.

Merge destroys provenance — you can't tell which branch produced which item. Collector's windowed fold doesn't guarantee one-from-each-branch. If one branch errors and the other succeeds, the behavior depends on arrival order. I killed both and built a Join.

## The pattern

Conceptual, quantitative, and structural errors were caught by the fresh-context adversarial reviewer. Context errors were caught by me. No single participant caught all four.

## Where the loop failed

Adversarial review is not correct review. The instrumentation advice would have delayed diagnosis.

Claude Code self-grades leniently. An A from self-assessment was typically a B from external review.

The embed instrumentation problem — semaphore wait counted as service time — survived multiple review rounds. A fresh-context reviewer can check "do these numbers add up?" It can't check "is this metric measuring what you think it's measuring?"

No reviewer asked "why not subprocess isolation for ORT?" until late in the process.

## Why this setup

Early on I bounced ideas across models to learn their relative strengths. Every model had blind spots, and having one catch another's made both more useful. I stopped because of cost and inconvenience.

I came back when the concurrency work got above my head. The pipeline implements Drum-Buffer-Rope on a Chromebook with 8.6GB available to the VM. I needed someone holding me to rigor on work I couldn't fully verify myself.

ChatGPT is mean. It's mean and it catches things. In this workflow, Claude Code was the stronger implementer and ChatGPT the stronger fresh-context critic. I decide what's true.

## What changed

Claude Code writes "we spent weeks on the wrong thing." I correct it. ChatGPT says to skip instrumentation. I override it. I notice a naming inconsistency, or a simpler way to express an API. I say so and Claude Code handles it.

Claude Code implements. ChatGPT checks. I set direction, correct facts, decide when to defer.

For this kind of work, the routing has held up.

---

*The indexer is [era](https://codeberg.org/binaryphile/era). The pipeline library is [fluentfp/toc](https://github.com/binaryphile/fluentfp). The review protocol is described in [The G/I Cycle](/development/2026/02/02/the-g-i-cycle-iterative-refinement-with-ai-assistants/).*
