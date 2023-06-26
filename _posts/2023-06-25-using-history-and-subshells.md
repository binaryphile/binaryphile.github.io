---
layout: post
title: "Using history and subshells"
date: 2023-06-25 12:00 UTC
categories: [ bash ]
---

So, it's been a while since I blogged.  Never mind that, it's never too
late to write another blog.  Let's just forget that I was supposed to be
in the midst of a series.  In order to simplify things, I'm just going
to do the normal blog thing and write some short posts with no greater
arc, just tidbits.  And that's good enough.

In this post, I want to outline a technique I've picked up lately, one
which I've not run across elsewhere.  I'm not claiming origination of
the idea, but I did have to discover it for myself.

TL;DR -- put common strings of commands in your history as subshell
commands.  While many like to use `&&` to stop on errors, I
stylistically prefer using errexit.  A subshell allows errexit with
semicolon-separated commands.  An example to commit and push all
changes:

```bash
> (set -e; cd "$PROJECT_ROOT"; git add .; git commit -m "$msg"; git push)
```

\- or to sync with main -

```bash
> (set -e; cd "$PROJECT_ROOT"; git fetch; git rebase origin/main; git push -f)
```

My typical use for this workflow is with `git` and `bazel` commands.
These tools usually require a short series of operations to do a useful
unit of work.  While the operations tend to be few, some may error.
When issuing commands one-at-a-time, interactively, one would typically
stop on an error and attempt a fix.

Bash doesn't have that behavior by default if you simply run a few
commands on one line (separate them with semicolons like many other
programming languages).  Because of this, most people write chained
commands that employ logical AND (`&&`) to check the result of the last
command and only run the next if the last command didn't report failure.

As a bash scripter, I am more used to enabling bash's builtin safety
features, such as errexit.  Errexit tells bash to stop (exit, actually)
whenever a command or function returns an error.  (_Unless_, the result
was part of an expression.  Any part except the last in the expression,
actually.)

That means any one-liners I write just need the standard semicolon
separator, not double-ampersand.  While it's not a huge deal, it's how I
think now and, as well, it does feel nice to use a home-row pinky
instead of a shift-and-reach-index-finger.

A typical workflow for me is to rebase on main prior to making a pull
request (maybe some fixing up as well, but not here for clarity).  I
don't bother keeping a local main checked out, so I just `git fetch` to
refresh the remote branch, then rebase on top of that.  A final force
push, `git push -f`, registers the new head with the remote.

So that reads:

```bash
git fetch
git rebase origin/main
git push -f
```

With errexit, and on a single line, it goes:

```bash
(set -e; git fetch; git rebase origin/main; git push -f)
```

If any step fails, then errexit stops the commands.  Notice I've put
parentheses around the entire command; this creates a copy of the
current shell, variables and all, prior to running the commands.

Since errexit forces a full exit, the subshell will stop and return
control to the current level of the shell (the one you ran the commands
from).

I'm also partial to subshells whenever using settings aside from
errexit.  For example, I almost always turn off globbing by default.  To
use a setting such as that for a few commands, a subshell creates a
sandbox that cannot affect your current shell once you've returned to
it.  So you never need to worry about interfering with your normal
interactive shell settings when you just need some programmatic
strictness for a few commands.

Also notice the handful of variables, such as `$msg` and
`$PROJECT_ROOT`.  `$msg` needs to be set per-commit, but `$PROJECT_ROOT`
can be set in a direnv file (a handy project tool) so these commands can
automatically adapt to the project at hand.

Finally, you only need to figure out a unique part of the command to
history search for it.

Why put these in history, rather than save them in bashrc or a bin
directory?  Because I like to use these commands as second nature, but
when I work with others, they have no idea what I'm doing (that's not
quite true, I have some other tools that help explain).  But being able
to see all of the commands explicitly on the command-line, people have a
chance if they get the time to read any of it, at least. :)  So it can
help people follow you as you work.

And when it comes to persistence concerns, I have eternal bash history
to save them, but that's a different post.
