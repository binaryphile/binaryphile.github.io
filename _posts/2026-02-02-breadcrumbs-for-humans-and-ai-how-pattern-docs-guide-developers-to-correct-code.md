---
layout: post
title:  "Breadcrumbs for Humans and AI: How Pattern Docs Guide Developers to Correct Code"
date:   2026-02-02 00:00:00 +0000
categories: development
---

A backend returns 200 OK with a JSON error body when downloads fail. This may seem unexpected at first. 200 indicates success. Arguably this is a protocol adherence issue, but it remains. Every new developer that works on downloads must learn this—one way or another. Every code review catches someone checking response.ok. The knowledge exists—in some developers' heads.

This is tribal knowledge. It doesn't scale. People leave, context-switch, or just forget. Code review becomes an oral tradition.

Pattern docs fix this. They externalize institutional knowledge into structured documentation that lives alongside the code. And because they're structured, AI assistants benefit too—but that's a bonus, not the point.

## The Problem: Knowledge That Doesn't Scale

Every codebase has conventions that aren't obvious from the code:

- Why we check Content-Type instead of response.ok
- When to use the cache freshness indicator (and when not to)
- Which ESLint rules we wrote ourselves and why

This knowledge lives in people's heads. It transfers through:

- Code review comments (repeated endlessly)
- Slack threads (unsearchable after a month)
- Onboarding conversations (different every time)
- Trial and error (expensive)

The result: inconsistent code, repeated mistakes, slow onboarding, and knowledge that walks out the door when people leave.

## The Solution: Pattern Documentation

Pattern docs capture the "why" behind conventions. They live in `docs/patterns/` alongside the codebase.

Each pattern doc answers:

- **What's the problem?** Code example of what fails
- **What's the solution?** Working code with comments
- **When do I use this?** Decision criteria
- **How do I find existing usages?** Grep command

### Example: Defensive File Download

**Problem:**

```javascript
// PROBLEMATIC - Don't use
const response = await fetch(downloadPath);
if (!response.ok) throw new Error('Download failed');
// This misses errors! The backend returns 200 OK with JSON error body
```

**Solution:**

```javascript
// Check Content-Type, not status code
const response = await fetch(downloadPath);
const contentType = response.headers.get('Content-Type');
if (contentType?.includes('application/json')) {
    const errorData = await response.json();
    throw new Error(errorData.error || 'Failed to download file');
}
```

**When to use:** User-initiated downloads needing error feedback

**When NOT to use:** Static CDN files, streaming large files (>100MB)

## Human Benefits

**Onboarding and knowledge preservation:** New developers read the pattern doc instead of discovering conventions through trial and error. When someone leaves, the knowledge stays. "Why do we do it this way?" has a documented answer that doesn't depend on who's in the room.

**Code review:** Instead of explaining the same convention repeatedly, link to the pattern doc. Review comments become "See docs/patterns/defensive-file-download.md" instead of a paragraph of explanation.

**Consistency:** When the pattern is documented, people follow it. When it's tribal knowledge, they reinvent it—differently each time.

**Discoverability:** Comments in code point to pattern docs:

```javascript
// See: docs/patterns/defensive-file-download.md
const response = await fetch(downloadPath);
```

Developers see the comment, follow the link, understand the context. The breadcrumb is right where they need it.

## AI Benefits (The Bonus)

If you document patterns for humans, AI assistants benefit automatically.

When an AI coding assistant reads code with a `// See: docs/patterns/...` comment, it follows the path. LLMs gather context before suggesting changes—a file path is an unambiguous signal.

The pattern doc answers what the AI implicitly asks: "Why is this code written this way? What constraints apply?"

**Before pattern docs:** AI suggests `if (!response.ok)`—correct generically, wrong for this codebase. Developer corrects it manually.

**After pattern docs:** AI reads the pattern doc, suggests the Content-Type check. No correction needed.

Same docs, two audiences. Write once, benefit twice.

## AI Assists (The Accelerator)

AI assistants don't just consume pattern docs—they help create them.

**The grade/improve loop:**

1. Describe the problem to the AI, show examples, let it draft
2. Ask the AI: "Grade this pattern doc—is it clear? Complete? Are the examples concrete?"
3. Prompt: "Improve" → the AI addresses its own critique
4. Repeat until satisfied
5. Apply your codebase knowledge, deploy, refine when reality reveals gaps

The AI handles the structure; you provide the institutional knowledge. Documentation that used to get postponed indefinitely now gets written.

## Patterns Evolve

Pattern docs aren't static. They evolve as real-world use reveals gaps.

**Example:** A custom ESLint rules pattern evolved over a few days:

- Initial version flagged a specific accessor option
- Refined to "all accessors should be suspect"—the initial scope was too narrow

**The update workflow:**

1. Discovery: Real-world use reveals the pattern is incomplete
2. Update the doc (source of truth)
3. Run Find References: `grep -rn "docs/patterns/your-pattern" src/`
4. Update code comments if needed

Bidirectional traceability—code points to docs, docs find code—makes updates systematic rather than "hope everyone got the memo."

## When This Doesn't Work

**Patterns requiring judgment:** "Choose appropriate log level" doesn't help anyone—human or AI. You need: "Use ERROR for user-facing failures, WARN for recoverable issues, DEBUG for everything else."

**Unstable conventions:** Patterns that change weekly create maintenance churn. Start with stable, mechanical conventions.

**Overhead:** Doc renames require updating all reference sites. Worth it for stable patterns; consider this before frequent reorganization.

## Getting Started

**Start with work you just finished:** You just fixed a bug or implemented a feature. Was there something non-obvious? A gotcha you discovered? Document it now while the context is fresh. That's your first pattern doc.

**Template:**

- **Problem Statement** - code example of what fails (and why)
- **Solution** - working code with comments
- **When to Use / When NOT to Use** - decision criteria
- **Find References** - grep command to locate usages

**Add the breadcrumb:** Put `// See: docs/patterns/your-pattern.md` in the relevant code. Now it's discoverable.

**Use AI to draft:** Describe the problem, let AI draft, grade/improve until satisfied.

## The Payoff

Document conventions for humans. AI assistants benefit automatically. AI assistants help you write the docs faster.

The knowledge that used to exist only in people's heads—now it scales.
