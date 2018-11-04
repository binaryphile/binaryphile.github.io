---
layout: post
title:  "Approach Bash Like a Developer - Part 27 - Traps"
date:   2018-09-23 01:00:00 +0000
categories: bash
---

This is part 27 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed returning values from functions.  This time,
let's discuss bash's [trap] facility.

It's a Trap!
------------

You know I had to.

Traps are signal handlers, where a signal is an operating-system defined
message which can be sent to a running process.  In our case, the
process is a script.

The operating system will interrupt whatever the script is doing and the
script will execute whatever handler it has defined for the particular
signal.

If the handler doesn't cause the script to exit, for example by calling
*exit*, then the script may continue running where it left off.  In the
case of bash scripts, if the command which was interrupted was an
external command, it is likely (but not guaranteed, depending on the
command) that the return code from the command will be an error.

This isn't due to bash, but rather because it will probably have also
received the signal and reacted to it independently.

Signals are actually numbers, but most programs also understand them via
names.

Some programs always refer to them with a "SIG" prefix, such as
*SIGTERM*.  Others understand the signal names without the prefix, such
as *TERM*.  Ones which understand the non-prefixed versions typically
understand both forms, as does bash.

The typical termination signals which are seen by programs include:

-   *SIGTERM* - 15 - terminate, the default signal sent by *[kill]* - it
    is a request for program termination

-   *SIGINT* - 2 - interrupt, the signal sent by Ctrl-C - it tells the
    program that it is being interrupted and should end itself, but
    should also communicate to the parent that it was interrupted and
    that's the reason why it exited

-   *SIGQUIT* - 3 - quit - like interrupt, but also produce a core dump

-   *SIGHUP* - 1 - hangup - sent when the controlling (pseudo-)terminal
    is disconnected or when the controlling process on a terminal exits

*SIGKILL* is another well-known termination signal, used by *kill -9*,
but it never makes it to the process.  The operating system instead
responds directly by killing the process with extreme prejudice, i.e. no
opportunity for the process to clean itself up.

There are other signals as well.  Run *kill -l* to see them all.

When a bash script runs a foreground command, any signal sent to bash
will not be handled until the command ends.

Bash also defines some pseudo-signals which can be handled with traps,
but do not always directly correspond to the defined signals, or differ
in their behavior from other shells.  They are more like events than
signals.  They include:

-   *EXIT* - when the process is exiting, pretty much for any reason

-   *ERR* - when the process exits because the *errexit* option was set
    and an error was encountered

-   *DEBUG* - used for debugging and variable tracing

I'll discuss the first two more later, but you'll have to do your own
research on *DEBUG* and the other signals I haven't mentioned.

The Trappist
------------

If you want to make use of traps in your scripts, there are a number of
typical use cases.  Some are described above, but here are other typical
ones:

-   cleanup - one of the most important use cases can be
    closing/deleting in-use resources when the script is going to exit

-   linearizability - preventing interruption when the script is doing
    something which is critical to complete

-   user communication - the user-defined signals can be sent by the
    user to notify the script of some event's occurrence

-   traceback on unplanned termination - my personal favorite for
    debugging purposes...what was going on when the program stopped?

Etc., etc...

The way you set a trap handler is with the trap command:

{% highlight bash %}
trap 'command(s)' SIGNAL [SIGNAL]...
{% endhighlight %}

Where *command(s)* is either a simple command/function call or a set of
commands separated by semicolons.

To reset a trap which has been set up by a prior *trap* command, either
call it with no command argument, or "-" for the command argument.  This
will reinstate the default handler for the signal, if there is one.

{% highlight bash %}
trap SIGNAL
trap - SIGNAL
{% endhighlight %}

And to ignore a signal using a trap, feed it a null argument (empty
quotes):

{% highlight bash %}
trap '' SIGNAL
{% endhighlight %}

Some guides mention using ":" (true) for the command argument to ignore
a signal, but it is not fully equivalent to a null argument.

If your trap should be available for the duration of your script, you
should set it prior to calling *main*, or near the beginning of your
script.

Here's an example of how to call a cleanup function when your script
gets the *INT* (e.g. Ctrl-C) signal:

{% highlight bash %}
cleanup () {
  rm $file
  trap - INT  # reinstate default handler
  kill -INT $$
}

trap cleanup INT

file=$(mktemp)
[...some other work happens, then the user hits Ctrl-C]
{% endhighlight %}

Here we're calling a function which we created expressly to handle the
signal.  First it removes the temp file we created.  This would be where
you might do other things, such as close a database connection, etc.

Since the signal can be sent multiple times, this function will be
called each time, perhaps interrupting itself.  If you are writing a
longer cleanup function, be aware it may be entered more than once and
may have partially completed beforehand.

For this reason, you may also want to revert or disable the handler if
you have commands which should not be invoked again once they are
successful, such as long-running ones.

Once the file is removed, we need to kill the script with the *INT*
signal as handled by the default handler, since *INT* needs special
treatment for the operating system's benefit.  See this article on [wait
and cooperative exit] for details.

In order to get the default handler back, we unset the trap we defined.
This is not something you'll usually need to do for other signals.

Finally, the script sends itself *INT*, which now triggers the default
handler.

If this were another trap which we wanted to cause the exit of the
script, we would have to call *exit* explicitly within the handler,
otherwise execution of the script would continue (*ERR* and *EXIT* are
exceptions to the rule).

Stage Left
----------

Rather than handling *INT* or the other termination signals explicitly,
it can be easier to use bash's *EXIT* "signal".

*EXIT* is triggered for pretty much any reason that the script is
exiting, so it is easier to define than remembering to list all of the
signals which might terminate your script.  *EXIT* also triggers on
*errexit*, which other signals don't (except *ERR*).  It is the most
useful of the termination-related signals.

Rather than trap on *INT* as above, trapping on *EXIT* is better:

{% highlight bash %}
file=$(mktemp)
trap 'rm $file' EXIT
[...]
{% endhighlight %}

Here we don't have to worry about disabling the trap or sending *INT*,
nor calling *exit*.  It's all been handled for us.

The only downside to *EXIT* is that you can't stop the exiting process
and resume script execution, if that's what you want.  It also does no
good to try to disable *EXIT* with a null argument.

Is Human
--------

*ERR* is another special "signal" which triggers when *errexit* is
tripped by a command failing.  Like *EXIT*, *ERR* can't be disabled with
a null argument, nor can it return to normal execution.

If *ERR* and *EXIT* are both set, *ERR* happens first, then *EXIT*.
Since you can't short-circuit them, if both are defined, then both will
run.

Continue with [part 28] - tracebacks

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-22-approach-bash-like-a-developer-part-26-returning-values          %}
  [trap]:         https://mywiki.wooledge.org/SignalTrap
  [kill]:         http://wiki.bash-hackers.org/commands/builtin/kill
  [linearizability]: https://en.wikipedia.org/wiki/Linearizability
  [wait and cooperative exit]: https://www.cons.org/cracauer/sigint.html
  [part 28]:      {% post_url 2018-09-24-approach-bash-like-a-developer-part-28-tracebacks                %}
