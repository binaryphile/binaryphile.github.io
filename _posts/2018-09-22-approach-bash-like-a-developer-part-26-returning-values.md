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

-   a form of [indirection]

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

The other good part is that using stdout works with pipelines, because
pipelines connect stdout to stdin.  In that case, the command
substitution is unnecessary, you just use the pipe character to take the
output from the command on the left and feed it to the input of the
command on the right.

One bad part about using stdout is that sometimes, if your function is
complex, some commands you use in the function may generate some
unexpected output. Since one output is the same as another to stdout, it
can adulturate your intended return value. Most of the time that's not
an issue, but it can surprise you.

The other bad part about it is that command substitution is not very
performant.  Command substitution creates a subshell, which involves
creating a new process that mirrors the existing shell.  While it may
not look expensive, it's a lot more than just returning a value.  In
fact, it's very expensive for such a small thing.

While performance probably isn't the first thing on your mind if you're
using bash, we'd still like our scripts to not be slower than they need
to be. Especially since they're already going to be slower than other
languages.

Global Variables
----------------

I've discouraged the use of global variables because they require the
caller and the function to agree on a variable name.  That's bad because
it ties namespaces together and can cause naming conflicts and subtle
bugs.

Most bash scripts do it anyway because you can't return hashes and
arrays easily, and globals are the simplest way to get around that.

Even so, globals have some other disadvantages, such as the fact that
they can't be used to return values from subshells. Subshells are a copy
of the parent shell and go away once they're done.  Since pipelines
invoke subshells for each part of the pipeline, the same is true of them
as well.  You can't return global values from subshells nor, by
extension, any part of a pipeline.

Subshells notwithstanding, you can at least do one thing to address the
issue of namespace conflicts.  If you adopt the convention of picking a
specific global variable to always return your values, you can at least
know that you won't have conflicts with any other variables, which is
especially true of any code which follows the same convention.

In some languages such as ruby and perl, the special single-underscore
variable holds the last result.  Underscore already has a special
purpose in bash, so I choose the convention of a double-underscore as a
return variable: `__`.

Since it may be used in any function call it has to be treated as
ephemeral, just like the special *$?* expansion.  It may, and probably
will, change from line to line, so in order to use its value, it needs
to immediately be saved off into another variable.  If you adopt this as
a practice, the same will apply for you.

So while this does use the global namespace, it avoids the concern of
naming conflicts to the greatest possible extent.  You also get the
performance of not using a subshell, so it's a suitable technique when
you need your code to be fast(ish).

The three things you need to remember for this technique to work are:

-   always save the value from `__` immediately if you plan to use it

-   you probably don't want to declare `__` as a local variable

-   don't try use it in subshells or, by extension, pipelines

Indirection
-----------

This is my preferred method of returning hashes and arrays, since it's
easy to work with them in the function, even though you have to
namespace your local variables.

The technique is to declare a local variable in the caller and pass it
to the function by name.  The function uses indirection to dereference
the variable name and pass the value back to the caller by setting that
variable.

The only concern with this is namespace collisions, although this time
it's between the local variables in the called function and the return
variable's name.  Any local variable in the function could accidentally
mask the return variable if they happen to have the same name, defeating
the indirection.

Since the function doesn't know what name the caller will pass, it has
to namespace all of its locals.  I like to namespace my locals with a
trailing underscore in this situation.

This method also doesn't work with subshells and pipelines.

In recent versions of bash, the best way to accomplish this is to
declare the recipient of a return variable name with *local -n*.  The
*-n* option allows you to initialize the variable with the name of
another variable. From then on, anything you do to the local variable is
reflected in the named variable:

{% highlight bash %}
myfunc () {
  local -n reference_=$1

  reference_=$2
}

myfunc one 1
echo $one
{% endhighlight %}

*myfunc* will set the variable *one* to *1*, via *reference_*.

Por Que No Los Tres?
--------------------

If you like the flexibility of being able to choose from any of these
methods it is possible to marry them.  Here's an example which converts
a string to all uppercase:

{% highlight bash %}
to_upper () {
  local string_=${1^^}  # force uppercase
  local ref_=${2:-}     # return variable name, if provided

  # adds "-v $ref_" if ref_ is present
  printf ${ref_:+-v$IFS$ref_} $string_
}
{% endhighlight %}

In this case, instead of *local -n*, we're using *printf -v* to return
the value.  This method still requires local namespacing. It works well
for strings, but isn't as flexible as *local -n* for working with arrays
or hashes.

To use it with stdout, simply don't provide a variable name:

{% highlight bash %}
result=$(to_upper "lowercase string")
{% endhighlight %}

To use it with the global `__`, pass it that name:

{% highlight bash %}
to_upper "lowercase string" __
do_something_with $__
{% endhighlight %}

Of course, this is piggybacking on the indirect method since we're using
*`printf -v __`* instead of setting `__` directly.  Normally you
wouldn't have to namespace the local variables and could just work with
`__` by its name.  It's only because we're trying to combine methods
that we're setting `__` indirectly.

To use it with indirection to a local variable, declare that name and
pass the name in:

{% highlight bash %}
myfunc () {
  local result

  to_upper "lowercase string" result
}
{% endhighlight %}

Returning Arrays via Strings
----------------------------

If not using indirection, you can still return array values via strings,
the same as passing them in as arguments.  Here it is with the global
method:

{% highlight bash %}
myfunc () {
  local myarray=( one two three )

  __=${myarray[*]}
}

myfunc
array=( $__ )
{% endhighlight %}

As I mentioned when discussing data types, I don't convert a string
variable type to an array variable type because it can't be changed back
without being unset.  I always treat the global `__` variable as a
string variable, so here the splat expansion is used to turn the array
value into a string.

Returning Hashes
----------------

Hashes may also be returned as a string. There isn't a method like the
splat expansion for hashes, so instead we have to use the *rep* function
we created earlier. Here it is with the stdout method (remember that
*rep* already uses stdout, so it can be the last call in the function):

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
  local expression_

  _err_=0
  expression_="^declare -[a|A] [^=]+='(.*)'$"
  [[ $(declare -p $1) =~ $expression_ ]] || {
    _err_=1
    return
  }
  printf ${ref_:+-v$IFS$ref_} ${BASH_REMATCH[1]}
}
{% endhighlight %}

Continue with [part 27] - traps

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-18-approach-bash-like-a-developer-part-25-passing-hashes            %}
  [descriptor]:   http://wiki.bash-hackers.org/syntax/redirection
  [indirection]:  http://mywiki.wooledge.org/BashFAQ/006#Indirection
  [command substitution]: http://wiki.bash-hackers.org/syntax/expansion/cmdsubst
  [part 27]:      {% post_url 2018-09-23-approach-bash-like-a-developer-part-27-traps                     %}
