---
layout: post
title: "Cockburn Use Cases Guide"
date: 2026-05-10 12:00:00 -05:00
categories: [ software-engineering, requirements, use-cases ]
canonical-source: "jeeves@1b3ca3b:guides/cockburn-use-cases-guide.md"
---

A practical reference for writing use cases per Alistair Cockburn's *Writing Effective Use Cases* (2001). Template, goal levels, and step-writing guidelines distilled for software teams that want to capture behavior without designing the UI.

*Originally authored as a working guide; published here on 2026-05-10 as part of the binaryphile.com compliance-references set.*

---

I keep returning to Cockburn's framework when a team needs to write down what the system actually does, in a form that survives implementation changes. This is the version I reach for when I'm reviewing requirements drafts.

---

## Template (Fully Dressed)

```
### UC-N: Active Verb Phrase (Goal)

- **Primary Actor:** Role name (singular, capitalized)
- **Goal:** What the actor wants to achieve
- **Scope:** System under design (the black box)
- **Level:** User goal | Summary | Subfunction
- **Secondary Actors:** External systems the SUD calls upon
- **Trigger:** Event that starts the use case
- **Preconditions:** What must already be true (not tested within the UC)
- **Stakeholders:**
  - Role — what they need from this use case (drives MSS, extensions, guarantees)
- **Main Success Scenario:**
  1. Triggering event / first interaction
  2. Actor does X; System responds Y
  ...
  N. Goal is achieved
- **Extensions:**
  - 3a. Condition detected as fact:
    1. Recovery step
    2. Resume step N / Fail / Separate success
- **Technology & Data Variations:** Sub-variations in how a step may be executed
- **Minimal Guarantee:** Promise to all stakeholders even on failure
- **Success Guarantee:** What must be true on completion
```

## Goal Levels

| Level | Test | Size |
|-------|------|------|
| **Summary** | "That's not just one thing" — encompasses multiple user goals | Hours |
| **User Goal** | Boss test: "Would your boss accept you did this all day?" EBP test: one person, one place, one time, measurable value | 3-9 steps, minutes |
| **Subfunction** | Needed to support a user-goal UC; not independently valuable | Seconds |

## The Three Kinds of Action Steps

Every step must be one of:
1. **Interaction** between two actors
2. **Validation** protecting a stakeholder's interest
3. **Internal state change** satisfying a stakeholder

## Twelve Step-Writing Guidelines

1. **Simple grammar.** Subject-verb-object.
2. **Who has the ball.** Name the actor explicitly in every step.
3. **Bird's-eye view.** Describe from above, not inside any actor's head.
4. **Process moves forward.** Each step advances toward the goal. No step leaves the scenario unchanged.
5. **Intent, not movements.** "Customer provides address" not "Customer clicks field and types."
6. **Reasonable transaction size.** Actor sends request+data, system validates, system updates state, system responds. One step or decomposed — use judgment.
7. **"Validate," don't "check whether."** "System validates credentials" moves forward; "System checks whether credentials are valid" requires an if/else branch. Validation failures go in extensions.
8. **Mention timing when it matters.** "System responds within 3 seconds."
9. **"Actor has System A kick System B."** When the primary actor causes inter-system communication.
10. **"Do steps x-y until condition."** For loops.
11. **Condition says what was detected.** Extensions state facts, not questions. "Invalid card number:" not "Is the card valid?"
12. **Indent condition handling.** Extension handling indented under the condition.

## Extension Rules

- Keyed to MSS step numbers: `3a`, `3b`, `*a` (any step)
- State conditions as **detected facts**, not questions
- Each extension ends one of three ways:
  1. Rejoins MSS at a specific step
  2. Reaches a separate success exit
  3. Ends in failure
- Brainstorm exhaustively — completeness comes from extensions, not the MSS
- Complex extensions can be extracted into sub-use cases

## Stakeholder Interests

- Ask: "Who cares, and what do they want?"
- The system responds to the actor while **protecting the interests of all stakeholders**
- Every interest must be addressed somewhere in the MSS, extensions, or guarantees
- This section is the key mechanism for **preventing missing requirements**
- Stakeholder interests drive MSS steps, guarantees, and extensions

## Preconditions and Guarantees

- **Preconditions:** Assumed true, not tested. Only state what's worth telling the reader.
- **Minimal Guarantee:** Fewest promises even on failure (e.g., "audit trail preserved")
- **Success Guarantee:** What must be true on completion, meeting all stakeholder interests

## Quality Tests

- **Boss Test:** Would your boss accept you doing this all day? (user goal level)
- **EBP Test:** One person, one place, one time, measurable value, consistent state?
- **Size Test:** MSS has 3-9 steps. 20+ means decompose.
- **Purpose-content alignment:** Does the goal match what the steps accomplish?

## Common Mistakes

1. **Designing the UI** — intent, not widgets
2. **Wrong goal level** — apply Boss/EBP/Size tests
3. **No primary actor** — every UC needs one
4. **Missing stakeholder interests** — leads to gaps
5. **CRUD explosion** — use "Manage X" and only extract complex operations
6. **Excessive precision** — rigor beyond what's needed wastes time
7. **Goal-content mismatch** — stated goal doesn't match steps

## Process

1. Find system boundary (scope)
2. Find actors — characterize each (technical skill, constraints, behavior patterns)
3. Find goals — exhaustive brainstorm per actor; produce **actor-goal list** table
4. Write stakeholder interests — the key mechanism for preventing missing requirements
5. Write preconditions and guarantees (minimal + success)
6. Write MSS (3-9 steps meeting all interests)
7. Brainstorm extension conditions exhaustively — completeness comes from here
8. Write extension handling — each ends in rejoin, separate success, or failure
9. Extract/merge sub-use cases as needed
10. Readjust the set
