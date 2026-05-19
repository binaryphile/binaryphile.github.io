---
layout: post
title: "Codifying a Bash Style Guide as ShellCheck Plugins"
date: 2026-05-19 12:30:00 -05:00
categories: [ bash, shellcheck, haskell ]
---

A style guide is just text. An enforced check is a tool that catches mistakes.

I have a [bash style guide](/2026/02/27/bash-style-guide.html) that I keep in a repo and re-read when I forget which way around the `*List` convention goes. I also have a [shellcheck fork with a plugin system](/bash/shellcheck/haskell/2026/05/19/adding-a-plugin-system-to-shellcheck/). The natural next step is to translate the guide into checks. That's [shellcheck-convention-plugin](https://github.com/binaryphile/shellcheck-convention-plugin), and it ships nine checks codifying nine rules.

This post is the catalog plus two lessons from building it. The lessons are the value; the catalog is reference.

## The catalog

| Check | Rule | Guide section |
|-------|------|----------------|
| SC9001 | Taint flows from unquoted parameter expansion to test/cmdsub contexts | §5 quoting |
| SC9002 | Command substitution result is tainted; quote it before using | §5 quoting |
| SC9003 | Quoting an already-quoted-by-context value is noise | §5 quoting |
| SC9004 | A variable cannot end in both `_` and `List` (the two mutually exclusive suffixes) | §3 naming |
| SC9005 | Numeric variables don't belong inside `[[ ... ]]` — use `(( ... ))` | §11 conditionals |
| SC9006 | Inclusive language in identifiers *and* comments | §3 naming |
| SC9007 | Function docstring shape: first body statement is a `# description` comment | §6 functions |
| SC9008 | `*List` is an IFS-newline-serialized string, not an array — disallow array operations on it | §3 naming + §7 arrays |
| SC9009 | A `local` declaration without initialization followed by an append (`x+=...`, `printf -v x`, `read x`) reads from outer scope | §6 functions + §15 FP-style |

Each check has positive (should fire) and negative (should not fire) test fixtures. The plugin ships as one `.so` and reports `Loaded plugin: libconvention-checks.so (9 check(s))` at startup. Each check has its own SC code so users can disable individuals with `--disable=SC9008`.

The codes are in the SC9xxx range. Upstream uses SC1xxx (parser), SC2xxx (analytics), SC3xxx (shell-dialect). SC9xxx is a convention I picked for plugins — it doesn't collide with anything upstream is likely to issue, and a future reader can tell at a glance that an SC9xxx warning is from a plugin, not from shellcheck core.

## Lesson 1: when the task and the guide disagree, the guide wins

SC9008 shipped backwards.

The task description said "warn on array operations applied to `*List` variables." I read that, wrote the check, shipped it. The fixtures passed. The check fired on `octopiList[0]` and didn't fire on `octopi[0]`. Looked correct.

It was inverted.

`*List` in my style guide means an IFS-serialized *string* — newline-separated values you read with `while IFS= read -r line`. Arrays use *plural* names: `octopi`, `requestedTests`, `filenames`. The task had been filed months earlier, when the convention was still in flux, and the wording reflected the older form where `*List` meant "array." By the time I implemented it, the convention had inverted. The clarification lived in a separate task I didn't read. I followed the task wording, not the guide.

The lesson: when implementing a rule, read the guide section, not the task description. Tasks describe *what to do*; guides describe *what's true*. If they disagree, the guide wins, because the guide is what users will be checked against.

The fix: `git revert`, file a corrected task, re-implement against the guide, write a process retro. The retro is the part that mattered — it's the reason I'll catch this class of mistake next time.

## Lesson 2: scope-aware checks are hard, and they're worth the trouble

SC9009 is the only check in the catalog that requires reasoning about variable *scope* and *order of operations* within a function. Everything else can be decided from the AST node in isolation.

The rule sounds simple:

> A `local x` declaration followed by an append (`x+=...`, `printf -v x ...`, `read x`, `(( x += ... ))`) without an intervening initialization is a bug. The append reads from outer scope before assigning, so the function silently captures and mutates a global.

Implementing it took 7 grade/improve cycles past the plan's approval, each finding a new defect class:

1. `read -p prompt var` — the `-p` value got treated as a write target. Fix: extract a `extractReadTargets` helper that knows which `read` flags take values.
2. `mapfile -t arr` — same flag-value bug for `mapfile`. Fix: shared `extractFlagAwareTargets` helper.
3. `declare -p name` — the `-p` form is a *query*, not a declaration. Fix: skip `declare` when `-p`/`-f`/`-F` is present.
4. `declare -n alias=...` — the `-n` form is a nameref, not a value. Fix: skip when `-n` is present.
5. `(( x )) ` — `TA_Variable` LHS of an arithmetic expression was being indexed as a read. Fix: track arith LHS IDs in a separate set, exclude from read positions.
6. `(( x = y = 1 ))` — chained arithmetic only registered the outer write. Fix: recurse into matched `TA_Assignment` for chained writes.
7. `printf -v var fmt` — the `-v` form *is* a write, but only when the flag is actually present. Fix: detect the `-v` flag explicitly rather than assuming any `printf` invocation with a variable arg is a write.

Each of these passed the previous round's fixtures. Each surfaced when I added one more real-world script to the negative-fixture set.

The check is still not CFG-path-sensitive. It's a *lexical* heuristic: walk the AST in order, build a per-scope index of `(variable, first-write-kind, first-read-or-write-position)`, flag when the first write is an append and there's no preceding initialization. A real CFG analysis would handle conditional initialization — `if foo; then x=1; fi; x+=more` — without flagging it. The lexical version flags it. That's a known false positive and it's documented in the check.

I shipped the lexical version because it catches the bug class — uninitialized-then-appended — without the implementation cost of a CFG. If I see real false positives in real scripts, I'll revisit. So far, the rate is low enough that the lexical heuristic is the right cost/benefit point.

## What this experiment proved

Before this work, my bash style guide was a document. People who read it (mostly me) tried to apply it; mistakes were caught in code review, when caught at all.

After this work, the guide is a *tool*. The same shellcheck I already run on save now refuses to let me declare `userList=( inky blinky )`, refuses to let me write `local count; count+=1`, refuses to let me write a function whose first body statement isn't a docstring comment.

The translation isn't perfect. SC9009 has known false positives. SC9007 fires on section-header comments that aren't intended as docstrings. SC9006 can't tell that `master` as a git branch context is allowed where `master` as a deployment role isn't. These are tradeoffs — false positives are cheaper to suppress than false negatives are to find by hand.

The repo: [binaryphile/shellcheck-convention-plugin](https://github.com/binaryphile/shellcheck-convention-plugin). The catalog with full per-check rationale: `docs/design.md` in that repo. The host fork: [binaryphile/shellcheck](https://github.com/binaryphile/shellcheck), covered in [the previous post](/bash/shellcheck/haskell/2026/05/19/adding-a-plugin-system-to-shellcheck/).

If you've written a style guide for any language and wish it were enforced, write a plugin for whichever linter your team already runs. The ROI is real. The first check costs a day; the second costs an hour.
