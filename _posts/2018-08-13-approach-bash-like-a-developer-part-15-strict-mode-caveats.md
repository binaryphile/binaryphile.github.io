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

Many Returns
------------

As mentioned in the discussion on strict mode, the left-hand side of a
boolean *&&* will not trigger errexit.  However, there can still be an
issue with errexit if the last line in your function is a boolean *&&*
expression.

When the left-hand of the expression returns false, the right-hand
portion will not be executed.  Since it is the last line in your
function, the function will then return, and it will return the value of
the last command executed. That's the conditional which returned false.

Even though the function will have executed correctly, it will return
false, and that return will cause errexit to trigger.

For this reason, you'll want to add a final *true* to the function if
you have a boolean *&&* as your last line.  Usually I just add a
semicolon and colon to the end of that line:

{% highlight bash %}
condition && follow_on;:
{% endhighlight %}

*:* is a bashism which is the same as *true*.  It's appropriate here
since we're keeping the code cleaner.

Another alternative is to use an *if then* statement instead of a
boolean *&&*.  The *if then* never returns the value of the condition as
its own return value.

Crack the Return Code
---------------------

Saving the return code of a command which has failed is also a challenge
with strict mode.  You can always toggle strict mode, but you can also
use boolean suspension.  There are two other options.

One trick is to cover both alternatives:

{% highlight bash %}
command && rc=$? || rc=$?
case $rc in
  0 ) echo true ;;
  * ) echo false;;
esac
{% endhighlight %}

Whether *command* succeeds or fails, the result code will be captured,
and errexit is suspended by the *&&*.

The other option is to use negation, which also defeats errexit:

{% highlight bash %}
! command
case $? in
  0 ) echo false;; # actual error code was lost
  * ) echo true ;;
esac
{% endhighlight %}

In this case, rc will be the opposite of the actual return code, i.e. it
will be 0 if *command* threw an error and 1 if it didn't.  That means
you lose the actual error code returned, if it was an error, but if all
you care about is whether an error was thrown or not, it works.

Return Codes on Your Functions
------------------------------

The *command && rc=$? || rc=$?* trick works well for external and
builtin commands, since they don't need errexit to detect when one of
their own internal steps goes wrong.  Your functions, however, do.

If you are coding your functions conscientiously, that means they are
written to detect their own error conditions and return an appropriate
code as the return value, rather than stop the script.

However, you still want errexit to work correctly so that the error
cases you haven't detected with your code still stop the script.  This
allows you to debug the script, and to prevent it from continuing with
faulty assumptions about the state of things.

In the past, I used to write functions so that they returned error codes
when appropriate, and then used an *||* to take action if they did:

{% highlight bash %}
myfunction || die "myfunction ran into an error!"
{% endhighlight %}

That method suspends errexit, which causes the issues I just mentioned.

Instead, I now write the function to return an error code in a
designated global variable instead.  I use *_err_* for that purpose.
This means that the function doesn't have to be tested with a boolean *||*.
Instead I check the variable after the function has finished:

{% highlight bash %}
myfunction
! (( _err_ )) || die "myfunction ran into an error!"
{% endhighlight %}

So in detectable error scenarios, I write the function to return a 0
return code and instead set *_err_*, which thus doesn't trip errexit.

In order for this to work, you have to remember to set *_err_=0* at the
beginning of your function so you don't accidentally get the last
function's value for *_err_*.

I also pretty it up with an alias:

{% highlight bash %}
alias noerror?='! (( ${_err_:-} )) || (exit $_err_)'

myfunction
noerror? || die "myfunction ran into an error!"
{% endhighlight %}

The *(exit $_err_)* is to reset the error value to the one passed via
*_err_*, which can then be picked up by *die* or whatever
function/command you choose to use.

Set on You
----------

Aside from errexit, nounset can be tricky as well.  Any reference to an
unset variable will exit.  If you can't be sure that the variable will
exist, you can always use bash's [default value parameter expansion]
like so:

{% highlight bash %}
echo "${myvar:-default value}"
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

Continue with [part 16] - recap

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-13-approach-bash-like-a-developer-part-14-updated-outline           %}
  [earlier post]: {% post_url 2018-08-09-approach-bash-like-a-developer-part-12-working-in-strict-mode    %}
  [*concorde.bash*]: https://github.com/binaryphile/concorde
  [default value parameter expansion]: http://wiki.bash-hackers.org/syntax/pe#use_a_default_value
  [part 16]:      {% post_url 2018-08-24-approach-bash-like-a-developer-part-16-recap                     %}
