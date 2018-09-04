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

-   add the command as part of an *or* expression which always returns
    true

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

False or True = True
--------------------

Because an error in bash is equivalent to a boolean *false*, by making
the command part of a boolean *or* expression we can change the return
to *true* and avoid triggering an error exit.

The basic idea is:

{% highlight bash %}
erroring_command || true
{% endhighlight %}

The portion of the expression on the left side of a boolean operator has
the exit on error mode suspended for its execution.  This allows the
right-hand portion to be evaluated, especially when the operation is
*or*.

Since the right-hand side in our case is always true, it makes the
entire expression return true and the script can continue.

Since it is used with some frequency, I tend to shorten the *|| true*
into a smaller idiom.  It's somewhat cryptic looking at first, but it's
used enough that it becomes easily recognizable:

{% highlight bash %}
erroring_command ||:
{% endhighlight %}

*:* is a bashism which is the same as *true*. The *||* operator doesn't
require a space between itself and *:*, so I just turn the expression
into a special symbol which means "turn off errexit for this command": *||:*.

Continue with [part 13] - implementing strict mode

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:  {% post_url 2018-08-09-approach-bash-like-a-developer-part-11-strict-mode               %}
  [part 13]:    {% post_url 2018-08-12-approach-bash-like-a-developer-part-13-implementing-strict-mode    %}
