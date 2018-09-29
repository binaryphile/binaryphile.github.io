---
layout: post
title:  "Approach Bash Like a Developer - Part 29 - Debugging"
date:   2018-09-27 01:00:00 +0000
categories: bash
---

This is part 29 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed tracebacks.  This time, let's talk about
debugging bash scripts.

Debugging bash scripts can be challenging.  Bash isn't exactly among the
top-tier languages when it comes to, well, anything, but especially for
tooling.

Basically with bash, what you see is what you get.  Fortuanately, it's
been around for a very long time, so we're not entirely scraping the
bottom of the barrel.

There are, for example, numerous editors and even IDEs which at the very
least have syntax highlighting.  As recommended in my [second post],
vim, for one, is a good choice.

Even something as basic as a syntax-highlighting editor can prevent a
lot of mistakes from happening to begin with, and prevention is always
better than needing a cure.  The tracebacks we implemented last time are
another good debugging tool.

However, bugs will inevitably occur.  When they do, you'll need some
tools in the toolbox.

As far as I can help, it boils down to three things:

-   bash's xtrace

-   manual [tracing]/print debugging

-   [bashdb]

Each technique can be useful.  I tend toward the quick and dirty before
moving on to more sophisticated tools.

Bash's xtrace
-------------

The number one tool I use for debugging scripts is bash's builtin
tracing facility.

Tracing is enabled with the *set -x* option, which is the short version
of *set -o xtrace*.

To enable tracing on a section of code, add the *set -x* command before
it.  Where you want it to stop, use *set +x*.

xtrace will output each line that will be executed, after resolving
expansions.  Each line is prefixed with a number of *+*s (pluses) to
show what level of shell the line is executing in.  Subshells and
sourcing increase the number of pluses.

If you need to see the source lines prior to expansion, you can use *set
-v* instead (short for *set -o verbose*).  I don't recommend using both
at the same time since each line will be shown twice, once before
expansion and once after.  xtrace is already pretty verbose.

Of the two, I find xtrace the more useful.

The best place to employ tracing is in tests, which are already focused
on a single portion of code and are easily triggered.  Let's take one of
our earlier ones as an example:

{% highlight bash %}
it "outputs a header"
  IFS=$'\n'
  result=$(traceback 2>&1)
  assert equal Traceback: $result
ti
{% endhighlight %}

Let's say we weren't getting the output we were expecting here.  The
easiest way to see what's going on is to add tracing:

{% highlight bash %}
it "outputs a header"
  IFS=$'\n'
  set -x
  result=$(traceback 2>&1)
  set +x
  assert equal Traceback: $result
ti
{% endhighlight %}

We trigger tracing right before we invoke the function and turn it off
right afterward.  You don't want to leave it on when shpec's assert
function runs since tracing generates a lot of output, and you'll want
to be able to scroll back and easily find your code's output.

Here's some sample output:

{% highlight bash %}
++++ traceback
+++ result='++++ local -i rc=0
++++ echo '\''
Traceback:'\''

Traceback:
++++ return 0'
+++ set +x
{% endhighlight %}

You can see that there are already some levels of subshell going on,
likely due to shpec.  Each line is shown as it executes, along with its
output afterward if there is any.

It takes a bit of getting used to reading the output, but it's easier
when it's your code.

Another useful technique to use in concert with tracing is to call your
code from the command-line itself, so you can play around with different
arguments more easily.  The fact that we have our *sourced?  && return*
line in the file makes it easy to source the file and then call our
functions directly.  Just source the file, then turn on tracing and call
the function.

If you're like me, you may have a fancy prompt which interferes with
tracing by putting out a bunch of junk.  An easy way to prevent this is
start a shell with no bashrc configuration:

    bash --norc.

Manual tracing
--------------

While we're at it, if we're running code from the command-line it's also
useful to put in a few extra *echo*s to see the state of important
variables.  The same technique can be done with xtracing as well.

It's really up to you to figure out what's important to see, so I don't
have a lot of tips on this, but here's one: if you're generating string
values from your functions and you aren't using the global or indirect
variable return methods, then make sure to put your tracing out on
stderr rather than stdout.  This works for the command line as well as
shpec tests.

Bashdb
------

Finally, there's bashdb, the actual bash debugger.  Bashdb is an
open-source tool inspired by *[gdb]*'s interface.  As such, if you've
ever worked on a command-line debugger in linux, you're probably
familiar with most of what bashdb is about.

The basic idea is that the debugger loads your code and let's you step
through it live, one command at a time if you wish.

Bashdb is even available in many distro's repositories, so for example
if you're on ubuntu, you can install it with *sudo apt-get install -y
bashdb*.  Otherwise you can also install it easily from source.

Once installed, you run it with:

    bashdb myscript script_args

In the debugger, you get a prompt with several possible commands at your
disposal:

-   *list* and "-" show the code after and before your current execution
    point, respectively

-   *print* allows you to print variable values, such as *print $n*

-   *next* and *step* allow you to run the next statement, either skipping
    over or stepping into functions, respectively

-   *finish* lets you step out of the current function

-   *continue* runs until the next breakpoint

Most of these commands can be used with short names like "n" for *next*.
Hitting *enter* with no command repeats the last command, which can also
be convenient.

Bashdb also supports breakpoints, watches and the like.  You'll have to
read the documentation for more detail.  It's very functional, and can
come in handy when you just can't find a bug any other way.

With regard to our code, there is one note about bashdb, which is that
it won't work with the *sourced? && return* line, nor with
*strict_mode*.  I just comment those out before debugging.

Lastly, if the ergonomics of command-line debugging just aren't for you,
there's a graphical interface to bashdb available with [Visual Studio
Code], which is available on all of the major platforms.  You have to
install the [bashdb plugin] to use it.

While I haven't tried it myself, if there's any tool I would expect to
manage putting a decent front end on bashdb, it would be VSCode.

Continue with [part 30] - option parsing

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-24-approach-bash-like-a-developer-part-28-tracebacks                %}
  [second post]:  {% post_url 2018-07-26-approach-bash-like-a-developer-part-2-vim                        %}
  [tracing]:      https://en.wikipedia.org/wiki/Tracing_(software)
  [bashdb]:       http://bashdb.sourceforge.net/
  [gdb]:          https://www.gnu.org/software/gdb/
  [Visual Studio Code]: https://code.visualstudio.com/
  [bashdb plugin]:  https://marketplace.visualstudio.com/items?itemName=rogalmic.bash-debug
  [part 30]:      {% post_url 2018-09-28-approach-bash-like-a-developer-part-30-option-parsing            %}
