---
layout: post
title:  "Approach Bash Like a Developer - Part 19.5 - Disabling Path Expansion"
date:   2018-09-09 00:00:00 +0000
categories: bash
---

This is part nineteen and a half of a series on how to approach bash
programming in a way that's safer and more structured than your basic
script.

See [part 1] if you want to catch the series from the start.

[Last time], we disabled word splitting.  This time, let's disable path
expansion.

Path Expansion
--------------

An implication to using unquoted expansions I mentioned in the last post
has to do with *[path expansion]*, or *globbing*.

If you followed the standard practice of quoting all of your expansions,
you were also getting protection from this automatic shell feature as
well.

After expansions and word splitting, bash looks for glob expressions and
matches them to files and directories in the current directory,
substituting any results it finds.

That means if you have a value which contains \*, *?* or *[chars]*, then
it will be checked against the filesystem and possibly changed.

For example, this echos "helloa", not "hello?":

{% highlight bash %}
touch helloa
myvar=hello?
echo $myvar
{% endhighlight %}

Inspecting the variable with *declare -p myvar* shows that it indeed has
the question mark in it.  It's the echo command which performs the path
expansion.

Mostly I don't concern myself with this, since the odds are typically
very low that a value I care about also happens to expand to a path.

However, be aware that it happens.  Without going further into detail,
I'll simply recommend that you disable path expansion in your scripts
using *set -o noglob* and only enable it when you need it.

Boolean?
--------

One interesting option this opens up is the ability to use glob
punctuation in function names, namely the question mark.

Que?

One of the affectations of ruby as a language is to make use of the
[question mark in method names].  Ruby uses them as a convention (not an
operator) to simply signify the return type of the method as a boolean
(or "truthy" object).

While I won't be borrowing much from ruby in this series, this is one
thing I've always found visually useful for comprehension in code.  A
pithy function name ending with a question mark can well replace a
longer and more expository name without one.

For this reason, you'll see me using question marks in some function
names.  For example, our *sourced* function will now become *sourced?*.

I won't bother relisting *support.bash* for such a small change, but I
will note that method names which include a trailing question mark
require the space between the function name and the parentheses in the
function definition.

Updated Outline
---------------

Given all of this, here's the updated version of our basic script
outline:

{% highlight bash %}
#!/usr/bin/env bash

IFS=''
set -o noglob

source $(dirname $(readlink -f $BASH_SOURCE))/../lib/support.bash

main () {
  hello_world
}

hello_world () {
  echo "hello, world!"
}

sourced? && return
strict_mode on

main $@
{% endhighlight %}

Notice the lack of need for quotation marks in the *source* and *main*
invocations, and the question mark on *sourced?*.

Continue with [part 20] - scoping

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-01-approach-bash-like-a-developer-part-19-disabling-word-splitting  %}
  [path expansion]: http://wiki.bash-hackers.org/syntax/expansion/globs
  [question mark in method names]: https://docs.ruby-lang.org/en/trunk/syntax/methods_rdoc.html#label-Method+Names
  [part 20]:      {% post_url 2018-09-01-approach-bash-like-a-developer-part-20-scoping                   %}
