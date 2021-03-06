---
layout: post
title:  "Approach Bash Like a Developer - Part 12 - Working in Strict Mode"
date:   2018-08-09 00:00:00 +0000
categories: bash
---

This is part twelve of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we showed the elements of a strict mode for bash.  This time,
let's discuss some of the implications of strict mode for how you approach
programming with bash.

Strictly Speaking
-----------------

Bash is very forgiving to errors and bash commands don't tend to have
the same success rate as functions typically do, at least in other
languages.

For these reasons, failure is something that has to be dealt with much
more frequently than you might expect. Scripts that might work fine most
of the time will exit unexpectedly when strict mode is enabled.

This is probably not a bad thing, since most of the time you'd want to
know that a command failed if you didn't know.

However, you really may not care that a command fails because it doesn't
matter.  There are plenty of examples of commands which fail because
what they are attempting to do has already been done.

There are three methods for dealing with "acceptable" errors:

-   find a method that doesn't error

-   toggle strict mode off and on

-   negate the command with an exclamation point

Then Don't Do That
------------------

The first method is to find a way to run the same function or command
without causing an error in the first place.

This is useful when the error that the command is reporting doesn't
matter to the rest of your program.  The archetypical example is making
a directory.  If the directory already exists, then that's all you were
trying to accomplish in the first place.

However, *mkdir* will error if you tell it to make a directory which
already exists.  Fortunately, there's an option to *mkdir* which will
suppress the error when the directory already exists: *--parents*, or
*-p*.

Similarly for the *rm* command, there's the *--force* option, or *-f*.
A number of commands have such a *force* option.

There are more examples, but this is a method you'll have to learn for
yourself, since it's command-specific.  The documentation is your
friend.

Toggle Strict Mode
------------------

If necessary, turn strict mode off and on again.  This is usually
required when you are sourcing code which wasn't written for strict
mode.

We'll make a function later to turn strict mode off and on so that we
can toggle it easily.

Bang, Not!
----------

Errexit does not apply to conditional expressions.  There are several
statements which are considered to have or to be conditional
expressions:

-   *if* and *while* statements

-   *&&* and *||* expressions

-   *!* negations

Note that in *&&* and *||* expressions, the final right-hand side can
still trigger errexit.  It's only the left-hand side (or sides, if
multiple are chained together) for which errexit is suspended.

The simplest of these is negation:

{% highlight bash %}
! erroring_command
{% endhighlight %}

Even when the command succeeds and is then negated (resulting in false),
the false doesn't trigger errexit because it's considered a conditional
expression.

Negation is usually my go-to way of disabling errexit for a command.
However, occasionally I go with the "or true" method if I need to ensure
that the result code isn't false.

"or true" makes the command the left-hand side of an *||* expression
where the right-hand side is *true*.  That ensures the result is always
true. It looks like this:

{% highlight bash %}
erroring_command || true
{% endhighlight %}

Since *:* is *true* in bash, I usually shorten it to:

{% highlight bash %}
erroring_command ||:
{% endhighlight %}

Continue with [part 13] - implementing strict mode

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:  {% post_url 2018-08-09-approach-bash-like-a-developer-part-11-strict-mode               %}
  [part 13]:    {% post_url 2018-08-12-approach-bash-like-a-developer-part-13-implementing-strict-mode    %}
