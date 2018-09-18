---
layout: post
title:  "Approach Bash Like a Developer - Part 23 - Passing Arguments"
date:   2018-09-13 01:00:00 +0000
categories: bash
---

This is part 23 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed naming and namespaces.  This time, let's
discuss passing arguments to functions.

Functions in bash don't carry a signature or prototype for their
arguments.  Instead, any arguments to the function appear as positional
arguments in the context of the function.

By definition, positional arguments are already local to the function,
so you don't need to do anything special to work with them.  However,
you can assign them to other variables if you want to be more
descriptive, or if you want to free up the positional argument array for
other purposes.  If you do, just remember to declare the named variables
locally.

Strings and Arrays and Hashes, Oh My
------------------------------------

Basic types, which I'll just refer to as strings from here on out since
I don't really use integers, are the only argument type supported in
bash.

Since positional arguments are just an array of strings, bash easily
handles passing strings to functions.  If we're only talking about
passing a single array, then bash can handle that easily as well, by
expanding the array when calling the function.

However, bash cannot easily handle passing multiple arrays, nor hashes.

For this reason, most people handle these kinds of arguments not as
arguments, but rather as global variables.  If the array or hash is
stored in a global variable, the function doesn't need to receive it as
an argument.

This works if you write both the function and the script in which it's
used.  It requires shared knowledge of the variable name between the
function and the code which owns the global namespace.

It's not a method for writing reusable code, however.  The point of
having arguments is so that functions and the code which calls them do
not share or have to know about each other's variable names.  This makes
them independent from each other.

So there should be another way to address the issue of passing hashes
and arrays as arguments to a function, one which uses the conventional
bash method of passing arguments.  We'll address this issue in another
blog entry.

Passing a Single Array
----------------------

Before we get into anything more complicated, we can briefly discuss the
case of a single array as argument.

If all you have to pass is an array, then as I mentioned before, you can
simply expand it:

{% highlight bash %}
myfunc () {
  echo "Arguments are $@"
}

myarray=( one two three )

myfunc ${myarray[@]}
{% endhighlight %}

If you have other arguments than the array, you can still pass them and
the array the usual way, so long as you pass the array last.  This lets
the array be an arbitrary length, and lets you take advantage of the
*[shift]* commmand:

{% highlight bash %}
myfunc () {
    local arg1=$1; shift
    local arg2=$1; shift

    echo "arg1 is $arg1"
    echo "arg2 is $arg2"
    echo "array is $@"
}

myarray=( one two three )

myfunc val1 val2 ${myarray[@]}
{% endhighlight %}

Default Arguments
-----------------

In many languages, you can specify a default value for an argument by
supplying it in the function signature.

Bash doesn't have a function signature per se, so you have to define
defaults differently, but it's still straightforward:

{% highlight bash %}
myfunc () {
  local arg=${1-default value}

  echo "Argument is $arg"
}
{% endhighlight %}

If you have several arguments, you can easily provide several defaults:

{% highlight bash %}
myfunc () {
  local arg1=${1-default value1}
  local arg2=${2-default value2}

  echo "Argument 1 is $arg1"
  echo "Argument 2 is $arg2"
}
{% endhighlight %}

This leads us to a problem, however.  With the above function, I can't
supply an argument for *arg2* if I want to use the default value for
*arg1*:

{% highlight bash %}
# Doesn't work
myfunc val_for_arg2
{% endhighlight %}

We could change *local arg1=${1-default value1}* to have a colon, as in
*local arg1=${1:-default value1}*.  Then we could feed in an empty
string for *arg1* to get the default value:

{% highlight bash %}
myfunc '' val_for_arg2
{% endhighlight %}

This would work, since the expansion with a colon will replace an empty
string with the default value.  However, that would prevent an empty
string from being a valid value to pass for that argument, which may or
may not be acceptable.

Instead, I prefer to make all optional arguments (arguments with a
default value) be [keyword arguments].  This lets you choose which
optional arguments to supply without having to worry about the other
default values.

Simple Keyword Arguments
------------------------

Bash doesn't support keyword arguments natively.  We could come up with
a sophisticated implementation, but that's not the point of this blog.
Instead, we'll do the simplest possible thing that could work.

The idea is to have a local variable within the function whose value is
set to a default, and then to accept an argument which consists of that
variable name, an equals sign and a value supplied by the user.

Since such an argument already has the format of an assignment in bash,
we could just iterate through the keyword arguments and *[eval]* them
individually.  Better still, we could eval them together as a single
string, since bash allows multiple assignments on one line.

Two observations: first, *eval*'ing the assignments would create globals
if we didn't force it with the *local* keyword.  While we may have
already declared locals for the arguments when specifying default
values, the caller isn't constrained from feeding our function other
keyword arguments which don't correspond and won't be masked.  We want
to ensure this doesn't happen, whatever the caller passes.

Second, the *local* keyword takes multiple assignments as well, and even
better, *it accepts expansions*.  The following works:

{% highlight bash %}
myfunc () {
  local required_arg1=$1; shift
  local keyword_arg2=default_value
  local $@

  echo "Required argument 1 is $required_arg1"
  echo "Keyword argument 2 is $keyword_arg2"
}

myfunc val1 keyword_arg2=val2 keyword_arg3=val3
{% endhighlight %}

One thing to notice here is that all keyword arguments must come after
the required arguments so that the required ones may be shifted and the
keywords can be fed to *local* as *$@*.

Unfortunately, if no keyword arguments are supplied, then *local*
changes its behavior instead to listing the current locals on stdout.
So we need to test for remaining arguments before calling it.  Since
that gets a bit uglier looking, let's make an alias called *kwargs*:

{% highlight bash %}
shopt -s expand_aliases
alias kwargs='(( $# )) && local'

myfunc () {
  local required_arg1=$1; shift
  local keyword_arg2=default_value
  kwargs $@

  echo "Required argument 1 is $required_arg1"
  echo "Keyword argument 2 is $keyword_arg2"
}
{% endhighlight %}

There you go, poor-man's keyword arguments in bash.

Continue with [part 24] - passing arrays.

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-17-approach-bash-like-a-developer-part-22.5-naming-and-namespaces   %}
  [shift]:        http://wiki.bash-hackers.org/commands/builtin/shift
  [keyword arguments]: https://en.wikipedia.org/wiki/Named_parameter
  [eval]:         http://wiki.bash-hackers.org/commands/builtin/eval
  [part 24]:      {% post_url 2018-09-16-approach-bash-like-a-developer-part-24-passing-arrays            %}
