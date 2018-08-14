---
layout: post
title:  "Approach Bash Like a Developer - Part 15 - Strict Mode Caveats"
date:   2018-08-13 00:00:00 +0000
categories: bash
---

This is part fifteen of a series on how to approach bash programming in
a way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we updated our outline script with strict mode.  This time,
let's discuss a couple more caveats about strict mode.

Suspension of Disbelief
-----------------------

As mentioned in an [earlier post], boolean expressions can suspend the
errexit setting.  This is the basis for the *||:* method of ignoring
errors:

{% highlight bash %}
erroring_command ||:
{% endhighlight %}

This is fine for simple commands such as *mkdir* or *grep*, or for
simple functions which don't contain much logic.

However, this becomes problematic when you want the benefit of errexit,
but you also need to use the function in a boolean expression.  For
example, you frequently see conditional execution of a command using
*&&*:

{% highlight bash %}
# show the contents of a directory but only if it exists
(cd some_directory 2>/dev/null && echo *)
{% endhighlight %}

If the left-hand portion of the expression is *cd*, that's not likely to
be of interest to us.  However, if it's your own complicated function
instead, then you may care very much that it should exit if it goes
wrong.

In fact, as we'll see later, we can even get bash to give us a traceback
of where the function went wrong, precisely like other languages do,
which can be very useful for debugging.

What can you do about it?  Well, not much actually.  Don't use
complicated functions as the left-hand side of a boolean expression,
unless you're sure they are well-tested and bug-free.

Also, avoid booleans if your code relies at all on the assumption that
an error will cause it to stop.  If your code relies on that assumption,
all bets are off when errexit is suspended.

Fortunately, this is generally under your control so long as you are
conscious of it.

Note that all of this applies to the condition of an *if then*
statement.  The condition of the *if* has errexit suspended for its
evaluation, just as booleans do.

Many Returns
------------

As detailed in the last point, the left-hand side of a boolean *&&* will
not trigger errexit.

However, there can still be an issue if it is the last line in your
function.  When the left-hand of the expression returns false, the
right-hand portion will not be executed.  Since it is the last line in
your function, the function will then return, and it will return the
value of the last command executed. That's the conditional which
returned false.

Even though the function will have executed correctly, it will return
false, and that return will cause errexit to trigger.

For this reason, you'll want to add a final *true* to the function if
you have a boolean *&&* as your last line.  Usually I just add a
semicolon and colon to the end of that line:

{% highlight bash %}
condition && follow_on;:
{% endhighlight %}

As mentioned before, *:* is the same as *true*.

Another alternative is to use an *if then* statement instead of a
boolean *&&*.  The *if then* never returns the value of the condition as
its own return value.

Crack the Return Code
---------------------

Saving the return code of a command which has failed is also a challenge
with strict mode.  You can always toggle strict mode, but you can also
use boolean suspension.  The trick is to cover both alternatives:

{% highlight bash %}
command && rc=$? || rc=$?
{% endhighlight %}

Whether *command* succeeds or fails, the result code will be captured,
and errexit is suspended by the *&&*.

Set on You
----------

Aside from errexit, nounset can be tricky as well.  Any reference to an
unset variable will exit.  If you can't be sure that the variable will
exist, you can always use bash's [default value parameter expansion]
like so:

{% highlight bash %}
echo "${my_var:-default value}"
{% endhighlight %}

A default value (after *:-* above) will prevent bash from flagging the
variable as unset and stopping the script.

Hopefully your variables will exist most of the time, so the need for
this technique should be minimal.

It can, however, be useful when you are assigning positional arguments
to variable names in a function:

{% highlight bash %}
my_function () {
  local arg1=${1:-}
}
{% endhighlight %}

This way, *arg1* is guaranteed to exist and can be referenced without
fear of triggering nounset, even if no argument was supplied in *$1*.

Continue with [part 16]

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-12-approach-bash-like-a-developer-part-13-implementing-strict-mode  %}
  [earlier post]: {% post_url 2018-08-09-approach-bash-like-a-developer-part-12-working-in-strict-mode    %}
  [*concorde.bash*]: https://github.com/binaryphile/concorde
  [default value parameter expansion]: http://wiki.bash-hackers.org/syntax/pe#use_a_default_value
