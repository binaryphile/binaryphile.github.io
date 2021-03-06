---
layout: post
title:  "Approach Bash Like a Developer - Part 24 - Passing Arrays"
date:   2018-09-16 01:00:00 +0000
categories: bash
---

This is part 24 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed passing general arguments and keyword
arguments.  This time, let's discuss passing arrays [by value].

General Disarray
----------------

As noted before, bash doesn't support passing arrays as an element in an
argument list.  If you have a single array, you can expand it to be
either part of or the entirety of an argument list, but that doesn't
work if you have two arrays to pass.

You could always pass a length parameter which tells the function
exactly how many of the arguments belong to the first array.  This is
annoying to parse on the receiving end however.  There needs to be an
easier way without falling back on the use of global variables.

Super Serial
------------

Since bash only supports passing strings, we need a way to easily turn
arrays into strings.  Once inside the function, we also need a way to
easily turn them back into arrays.  This is a process usually referred
to as [serialization], although we're using it to interface between
function calls and not across network interfaces.

It would be easiest to reconstitute an array if we could use the regular
bash declaration syntax.

Without word-splitting, a single argument with the whitespace-separated
items of the array wouldn't work if we tried to do this:

{% highlight bash %}
array=( $argument )
{% endhighlight %}

That would result in an array with a single element containing all of
the items.

*eval* could make this happen this way, since the entire string will be
re-evaluated:

{% highlight bash %}
eval "array=( $argument )"
{% endhighlight %}

However, we can also use *local*, and *local* looks a bit more friendly.
The trick is to use the *-a* option and put the parentheses (or the
whole thing) in a string.

This makes *local* do a second pass of evaluation after the expansion:

{% highlight bash %}
local -a "myarray=( $argument )"
{% endhighlight %}

The question is, how to get the argument in the right syntax.  If the
array elements don't have spaces, things are easy...just use spaces
between the array elements (reminder, *IFS* is empty):

{% highlight bash %}
myfunc () {
  local -a myarray="( $1 )"

  # inspect myarray to see whether it worked
  declare -p myarray
}

argument="one two three"

myfunc $argument
{% endhighlight %}

So, that works pretty well.  There is one potential pitfall, which is
that this technique doesn't preserve the same indexing if the elements
of the original array are sparse.  The new array starts at index zero
and is contiguous.  I've never run into a situation where this is a
problem, but it could be.

The real problem with this technique is that once you have an array
which contains values with spaces, things get more complicated.  You
could put quotes in the value:

{% highlight bash %}
argument='"a value" "another value"'

myfunc $argument
{% endhighlight %}

However, it's difficult to do that if you already have an array and
have to generate the argument value:

{% highlight bash %}
argument=( "a value" "another value" )

# Doesn't work
myfunc $(printf '%s ' ${argument[@]})
{% endhighlight %}

You can't just slap quotes on the elements either, because
values with quotes will then mess it up:

{% highlight bash %}
argument=( 'a "value"' )

# Doesn't work - quotes are lost
myfunc $(printf '"%s" ' ${argument[@]})
{% endhighlight %}

There are a couple options here.  The first is to take advantage of
*declare -p*.  It generates the *eval*able statement to declare the
array, no matter how thorny the values:

{% highlight bash %}
myfunc () {
  eval $1

  declare -p argument
}

argument=( "a value" "another value" )

myfunc $(declare -p argument)
{% endhighlight %}

Without doing some rehabilitation on the resulting declaration however,
you're stuck with the variable name used by the caller when you're
*eval*ing it inside the function.  We want our variable names to be
independent between the caller and callee.

Another option is to use escaping.  Bash's *printf* command provides a
format which escapes any characters in values which could mess up an
*eval*, including spaces.  If we take care of the spaces, we don't need
to worry about much else, but *printf* will take care of the characters
we haven't thought about yet too.  It's designed for this:

{% highlight bash %}
argument=( "a value" "another value" )

myfunc $(printf '%q ' ${argument[@]})
{% endhighlight %}

This works, but it's still not pretty.

The best method I've found, however, is the ascii field-separator
method.

Separating Fields for Fun and Profit
------------------------------------

We can take advantage of *IFS* to merge and split arrays to and from
strings.  That's what it's made for, after all.  The problem with word
splitting before was the fact that it was set to use whitespace.  If
*IFS* is set to use a character which is never used in values, it can be
useful and presents no danger to the values we want to preserve.

The [ascii unit separator] is such a character.  It's a non-printable
control character created for the purpose of separating fields in a
record in such a way that it can't be mistaken for data in the field
(nor data in the field being mistaken for a separator).

As it happens, *IFS* can be set to this value:

{% highlight bash %}
IFS=$'\037' # ascii unit separator

myfunc () {
  local myarray=( $1 )

  declare -p myarray
}

argument=( "a value" "another value" )

myfunc "${argument[*]}"
{% endhighlight %}

Notice that the *local* declaration becomes simpler again.  Also notice
that the splat expansion  on the last line requires quotes in order to
get it to use the unit separator to join the elements of the array into
a single string.

That's because word splitting is enabled again, it's just splitting on
the unit separator character now, so there's no danger of splitting our
actual values.  When the argument is word-split, it results in the
normal literal syntax for an array assignment.

Simple, and effective.  Now that's what I'm talkin' about! Of course,
the caveat about sparse array indexing applies, but that's true of all
of these methods.

It's so effective in fact, that there's no reason not to use it all the
time.  We can replace our empty *IFS* assignment in our script template
with this *IFS* declaration instead.

Continue with [part 25] - passing hashes

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-13-approach-bash-like-a-developer-part-23-passing-arguments         %}
  [by value]:     https://en.wikipedia.org/wiki/Evaluation_strategy#Call_by_value
  [serialization]: https://en.wikipedia.org/wiki/Serialization
  [ascii unit separator]: https://en.wikipedia.org/wiki/Delimiter#ASCII_delimited_text
  [part 25]:      {% post_url 2018-09-18-approach-bash-like-a-developer-part-25-passing-hashes            %}
