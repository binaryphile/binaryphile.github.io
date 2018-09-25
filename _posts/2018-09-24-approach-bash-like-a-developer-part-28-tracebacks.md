---
layout: post
title:  "Approach Bash Like a Developer - Part 28 - Tracebacks"
date:   2018-09-24 01:00:00 +0000
categories: bash
---

This is part 28 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed traps.  This time, let's use them to create
tracebacks.

Tracebacks
----------

The most useful thing to do with *ERR* is to implement the kind of
tracebacks you see in other languages.  I'm basing this on ruby's
tracebacks, although python's would be another good example.

Let's work this up step by step.  Let's create a function which we'll
end up calling from the *trap* statement.  We'll call it *traceback*.

First, we want the function to preserve the return code of the command
which caused the error, so the script still exits with the same exit
status it would have otherwise.

*shpec/support_shpec.bash:*

{% highlight bash %}
describe traceback
  it "returns the return code of the triggering event"
    (
      set -o errexit
      trap traceback ERR
      false
    ) 2>/dev/null
    assert equal 1 $?
  ti
end_describe
{% endhighlight %}

This test runs in a subshell.  The fact that we trigger *errexit*, which
normally exits the script, only means that it exits the subshell.  That
allows us to test the result code of the subshell.

The *trap* statement wires up our traceback error handler, which is no
surprise.

The following *false* statement causes *errexit* to trigger, calling our
handler.

Passing this test is easy:

*lib/support.bash:*

{% highlight bash %}
traceback () {
  return $?
}
{% endhighlight %}

Normally a trap handler might call *exit* to stop the script, but *ERR*
is guaranteed to exit already, so I'm just using *return*.

Next, let's add a header which says "Traceback:" after a newline.  It'll
be output on stderr.  Since I'm only dealing with output here, I won't
bother wiring up *errexit* or the *trap*.  I'll set *IFS* here to strip
newlines from the result, since I'll be adding some in the output:

{% highlight bash %}
it "outputs a header"
  IFS=$'\n'
  result=$(traceback 2>&1)
  assert equal Traceback: $result
ti
{% endhighlight %}

Since command substitution captures stdout and not stderr, there's a
redirection to put stderr on stdout instead with *2>&1*.

Here's the code:

{% highlight bash %}
traceback () {
  local -i rc=$?

  echo $'\nTraceback:' >&2
  return $rc
}
{% endhighlight %}

Next, Let's add a message about the exit status on the last line of
output.

Since we'll be adding more lines of output on each test, I'll split the
result on newlines and set the positional parameters to the results:

{% highlight bash %}
it "outputs the exit status on the last line, indented"
  IFS=$'\n'
  set -- $(traceback 2>&1)
  assert equal '  Exit status: 0' ${!#}
ti
{% endhighlight %}

The expression *${!#}* is shorthand for "the last positional argument".

Our updated *traceback*:

{% highlight bash %}
traceback () {
  local -i rc=$?

  echo $'\nTraceback:'
  printf '  Exit status: %s\n\n' $rc
  return $rc
} >&2
{% endhighlight %}

Did you know that a redirection *after* the body of a function is still
part of the function body and happens when you call the function?
Neither did I, until I did.  Now do you too, don't you?

Next, I'd like the offending script line to be output in source form.

{% highlight bash %}
it "outputs the source line"
  IFS=$'\n'
  set -- $(traceback 2>&1)
  assert equal '  Command: set -- $(traceback 2>&1)' $2
ti
{% endhighlight %}

In order to get this, we'll need two pieces of information: the filename
and the line number.  Since the error may be in another file, we can't
rely on *BASH_SOURCE*...fortunately there's a bash function called
*[caller]* which will provide the correct information.

*caller* takes a frame number as an argument, starting with *0* for the
local function.  Increasing numbers walk up the [frame stack], until
there are no more frames, at which point *caller* returns false.

*caller* returns a line with the line number, filename and function
name, separated by spaces.  Don't try running *caller* at the command
line though, since it only works in scripts.

We'll parse out the line number and use *[sed]* to grab the line from
the filename.

We'll tell *sed* not to echo lines by default, then to pick the line
number specified, strip the leading whitespace on the line, then print
the result.  The expression is thorny enough that it helps to *printf*
it to a variable, since that is easier to read:

{% highlight bash %}
traceback () {
  local -i rc=$?
  local IFS
  local expression

  IFS=' '
  echo $'\nTraceback:'
  set -- $(caller 0)
  printf -v expression '%s s/^[[:space:]]*// p' "$1"
  echo -n '  Command: '
  sed -n "$expression" "$3"
  printf '  Exit status: %s\n\n' $rc
  return $rc
} >&2
{% endhighlight %}

Ok, now let's get to the real substance of the traceback, the call
stack.

What we're looking for looks something like this:

{% highlight bash %}
Traceback:
  Command: source_line
  script_file:line_number:in 'local_function'
  script_file:line_number:in 'calling_function'
  [etc., up to the top-level function]
  Exit status: return_code
{% endhighlight %}

We'd like the file name, the line number and function which was
executing when we hit the error.  As already mentioned, *caller* handles
this for us.

I'll break the test into three parts, one for each of the elements of
information we're looking for, so I'll break apart the line on ":" and
test each part:

{% highlight bash %}
it "prints the erroring file"
  IFS=$'\n'
  set -- $(traceback 2>&1)
  IFS=:
  set -- $3
  assert equal support_shpec.bash $(basename $1)
ti

it "prints the line number"
  IFS=$'\n'
  set -- $(traceback 2>&1)
  IFS=:
  set -- $3
  [[ $2 == *[[:digit:]] ]]
  assert equal 0 $?
ti

it "prints the function"
  IFS=$'\n'
  set -- $(traceback 2>&1)
  IFS=:
  set -- $3
  assert equal "in 'source'" $3
ti
{% endhighlight %}

Each test breaks up the third line of output on colons and then tests
the appropriate element.  For the filename test, the path may change
based on where the test is run from, so we use *basename* to just test
the filename.

For the line number, it may vary based on edits made to the shpec file,
so we just test for a digit.  One digit is enough.

For the function name, at the top level the shpec file is sourced by
shpec, so the function name is "source" as well.

{% highlight bash %}
traceback () {
  local -i rc=$?
  local IFS
  local expression

  IFS=' '
  echo $'\nTraceback:'
  set -- $(caller 0)
  printf -v expression '%s s/^[[:space:]]*// p' "$1"
  echo -n '  Command: '
  sed -n "$expression" "$3"
  echo "  $3:$1:in '$2'"
  printf '  Exit status: %s\n\n' $rc
  return $rc
} >&2
{% endhighlight %}

This version of the traceback satisfies our test, but only outputs the
current stack frame, while we want to trace up the stack.  An additional
test verifies that when called two levels deep in the stack, the second
layer of the traceback has the "source" line this time:

{% highlight bash %}
it "prints a top-level function two levels deep"
  f1 () {
    traceback
  }
  IFS=$'\n'
  set -- $(f1 2>&1)
  IFS=:
  set -- $4
  assert equal "in 'source'" $3
ti
{% endhighlight %}

A loop on *caller* handles navigating the stack:

{% highlight bash %}
traceback () {
  local -i rc=$?
  local -i frame=0
  local IFS
  local expression
  local result

  IFS=' '
  echo $'\nTraceback:'
  while result=$(caller $frame); do
    set -- $result
    (( frame == 0 )) && {
      printf -v expression '%s s/^[[:space:]]*// p' "$1"
      echo -n '  Command: '
      sed -n "$expression" "$3"
    }
    echo "  $3:$1:in '$2'"
    (( frame++ ))
  done
  printf '  Exit status: %s\n\n' $rc
  return $rc
} >&2
{% endhighlight %}

That's pretty good.  Now all you have to do is wire up *traceback* to
the *ERR* signal in your code:

{% highlight bash %}
trap traceback ERR
{% endhighlight %}

We could go so far as to add this to our existing *strict_mode* function
so that we always get tracebacks when *errexit* is enabled, but I think
that's enough for one post.

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-23-approach-bash-like-a-developer-part-27-traps                     %}
  [caller]:       http://wiki.bash-hackers.org/commands/builtin/caller
  [frame stack]:  https://en.wikipedia.org/wiki/Call_stack
  [sed]:          http://www.grymoire.com/Unix/Sed.html
