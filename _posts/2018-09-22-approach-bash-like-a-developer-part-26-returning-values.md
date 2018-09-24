---
layout: post
title:  "Approach Bash Like a Developer - Part 26 - Returning Values"
date:   2018-09-22 01:00:00 +0000
categories: bash
---

This is part 26 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed passing hashes as arguments to functions.
This time, let's discuss returning values from functions.

Functions in bash already have return values, of course.  I've been
calling them return codes because they really are just values to
indicate success or failure.

The *return* statement returns a number from 0-255 which can be tested
for truth or made part of an expression via the *$?* expansion.  Since 0
indicates success, the truthiness of a return is opposite what you would
get in other languages, as well as in arithmetic expressions.  0 is
*true* and any other (positive) number is *false*.

The problem is that bash deals in strings, and a function which returns
a byte isn't very useful for that.  We'd like it to be able to return
strings, arrays or hashes.

Since a function can't return anything other than a return code, there
are three ways to deal with returning a string as well, by using the
following:

-   stdout

-   a global variable

-   a form of [indirection], usually *printf -v*

Stdout
------

External commands typically put their output to stdout for the user to
see.  In scripts, it's common to take such output and process it into
data for the script to use in its logic.  [Command substitution] is the
typical way to absorb output:

{% highlight bash %}
textfiles=$(find . -name '*.txt')
{% endhighlight %}

If we write our own functions to be used this way, all we need to do is
echo output:

{% highlight bash %}
myfunc () {
  echo "this is my return value"
}
{% endhighlight %}

The good part about this is that it's simple to do:

{% highlight bash %}
# myfunc's output is the first argument to another_func
another_func $(myfunc)
{% endhighlight %}

The last good part is that using stdout is that it works with pipelines,
because pipelines connect stdout to stdin.  In that case, the command
substitution is unnecessary.

The bad part is that sometimes, if your function is complex, stdout has
a way of accidentally getting output from other commands mixed into it
if you aren't careful.  Most of the time that's not an issue, but it can
surprise you.

The other bad part about it is that it's not very performant.  Command
substitution creates a subshell, which involves creating a new process
which mirrors the existing shell.  While it may not sound intensive,
it's a lot more than is required to just return a value in most
languages.  In fact, it's very expensive by comparison.

While you're probably not using bash because you care about performance,
we'd still like our scripts to not be slower than they need to be,
especially since they're already going to be slower than other
languages.

Global Variables
----------------

I've already been poo-pooing the use of global variables, but this is
how most people do it if they don't want the expense of a subshell.

This can be fine, it just makes code less testable and reusable, since
you're now tied to a particular variable name, and the calling code
needs to be aware of the name.  If other code happens to want the same
variable name, they can conflict.

One other disadvantage of global variables is that they can't be used to
return values from subshells, since subshells are a copy of the parent
shell and go away once they're done.  Since pipelines invoke subshells
for each part of the pipeline, the same is true of them as well.

However, after all that, the global variable method is my preferred
method.  I just do one thing different which makes it more acceptable.
To avoid namespace collisions, I adopt the convention of only ever using
one specific global variable.  I chose one which should have a minimal
chance of accidentally being chosen by anyone else: double underscore.

In some languages such as ruby and perl, the special single-underscore
variable holds the last result, and that's what I'm getting at with this
variable.  Bash already has a single-underscore variable, however, so
double-underscore is the next best thing.

Since I may use it in any function I write and therefore any function I
may call, my variable has to be treated as ephemeral, just like the
special *$?* expansion.  It may, and probably will, change from line to
line in my code, so in order to use its value, I need to immediately
save it off into another variable.  If you adopt it as a practice, the
same will apply for you.

So while this does use the global namespace, it avoids the concern of
naming conflicts to the greatest possible extent.  You also get the
performance of not using a subshell, so it's a suitable technique when
you need your code to be fast(ish).

The three things you need to remember for this technique to work are:

-   always save the value from __ immediately if you plan to use it

-   never declare __ as a local variable

-   don't use it in subshells or, by extension, pipelines

Indirection
-----------

The last technique is to declare a local variable in the caller and pass
it to the function by name.  The function uses indirection to
dereference the variable name and pass the value back to the caller by
setting that variable.  This technique relies on the fact that bash uses
dynamic scoping, so the caller's variable is accessible to the function.

The only concern with this is namespace collisions, although this time
it's between the local variables in the function and the reference name.
Any local variable in the function could accidentally mask the caller's
variable if they happen to have the same name and then the result won't
be saved to the caller's variable.

Since the function doesn't know what name the caller will pass, it has
to namespace all of its locals.  I like to namespace my locals with a
trailing underscore in this situation.

This method has the same caveats as the global one when dealing with
subshells and pipelines.

Por Que No Los Tres?
--------------------

If you like the flexibility of being able to choose from any of these
methods it is possible to marry them.  Here's an example which converts
a string to all uppercase (*blank?* tests if the variable is empty):

{% highlight bash %}
to_upper () {
  local string_=${1^^}  # force uppercase
  local ref_=${2:-}     # return variable name, if provided

  ! blank? $ref_
  case $? in
    0 ) printf -v $ref_ $string_;;
    * ) echo $string_           ;;
  esac
}
{% endhighlight %}

To use this with stdout, simply don't provide a variable name:

{% highlight bash %}
result=$(to_upper "lowercase string")
{% endhighlight %}

To use it with the global \__, pass it that name:

{% highlight bash %}
to_upper "lowercase string" __
result=$__
{% endhighlight %}

Of course, this is piggybacking on the indirect method.  Normally you
wouldn't have to namespace the local variables and could just set __
directly.  It's only because we're trying to combine methods that we're
setting __ indirectly.

To use it with indirection to a local variable, declare that name and
pass the name in:

{% highlight bash %}
myfunc () {
  local result

  to_upper "lowercase string" result
}
{% endhighlight %}

Returning Arrays
----------------

Returning arrays works the same as passing them in as arguments.  Here
it is with the global method:

{% highlight bash %}
myfunc () {
  local myarray=( one two three )

  __=${myarray[*]}
}

myfunc
array=( $__ )
{% endhighlight %}

As I mentioned when discussing data types, I never convert a string type
to an array type variable because it can't be changed back without being
unset.  I always treat the global __ variable as a string variable, so I
use the splat expansion to turn the returned array into a string when
using it.

Returning Hashes
----------------

Returning hashes works the same way, by using *rep*.  Here it is with
the stdout method (remember that *rep* already uses the same method, so
it can be the last call in the function):

{% highlight bash %}
myfunc () {
  local -A myhash=( [zero]=0 [one]=1 [two]=2 )

  rep myhash
}

declare -A hash=$(myfunc)
{% endhighlight %}

Before we're done, let's redo the *rep* function to use the return
methods based on how it's called:

{% highlight bash %}
describe rep
  it "generates a representation of a hash on stdout"
    declare -A samples=(
      [zero]=0
      [one]=1
    )
    result=$(rep samples)
    assert equal '([one]="1" [zero]="0" )' $result
  ti

  it "generates a representation of a hash in a named variable"
    declare -A samples=(
      [zero]=0
      [one]=1
    )
    rep samples result
    assert equal '([one]="1" [zero]="0" )' $result
  ti
end_describe
{% endhighlight %}

{% highlight bash %}
rep () {
  local ref_=${2:-}
  local rep_

  rep_=$(declare -p $1)
  rep_=${rep_#*\'}
  rep_=${rep_%\'}
  ! blank? $ref_
  case $? in
    0 ) printf -v $ref_ $rep_ ;;
    * ) echo $rep_            ;;
  esac
}
{% endhighlight %}

Continue with [part 27] - traps

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-18-approach-bash-like-a-developer-part-25-passing-hashes            %}
  [descriptor]:   http://wiki.bash-hackers.org/syntax/redirection
  [indirection]:  http://mywiki.wooledge.org/BashFAQ/006#Indirection
  [command substitution]: http://wiki.bash-hackers.org/syntax/expansion/cmdsubst
  [part 27]:      {% post_url 2018-09-23-approach-bash-like-a-developer-part-27-traps                     %}
