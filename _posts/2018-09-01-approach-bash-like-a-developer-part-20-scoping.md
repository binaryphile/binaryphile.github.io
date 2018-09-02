---
layout: post
title:  "Approach Bash Like a Developer - Part 20 - Scoping"
date:   2018-09-01 01:00:00 +0000
categories: bash
---

This is part twenty of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we disabled word splitting and path expansion.  This time,
let's discuss variable scoping.

Bash Scoping
------------

Most languages employ what is termed *[lexical scoping]*.  In general,
there is a global scope and a local scope.  Global variables are
available everywhere, usable from any function.  Locally-scoped
variables are available only within their own function and nowhere else.

Lexical scoping makes it easy to reason about local variables because
they can't be modified unexpectedly.  Only your function gets to change
them.

Bash, however, is not lexically scoped.  Bash uses what is called
*[dynamic scoping]*.  There are still global and local scopes, but the
local scope is not as sacrosanct as it is in lexical scoping.

In dynamic scoping, a local variable is accessible not only to its own
function, but also to any function it calls.  The function's local
variables appear as global variables to any function it calls.

That's a problem.  In lexical scoping, you can count on a local variable
staying the same value from line to line.  It only changes if you change
it.  With dynamic scoping, however, you never know if a function you
just called has changed any of your own local variables.  Every function
call therefore becomes a leap of faith.

For example, consider the following code:

{% highlight bash %}
IFS=''
set -o noglob

outer_function () {
  local lvar

  lvar=one
  inner_function
  echo $lvar
}

inner_function () {
  lvar=two
}

outer_function
{% endhighlight %}

The *local* keyword declares *lvar* to be local to *outer_function*.
When *outer_function* calls *inner_function* however, *inner_function*
operates on the *lvar* in the closest enclosing scope, which belongs to
*outer_function*.  As a result, *outer_function*'s *lvar* is changed to
"two", and that's what *outer_function* echos.

If you're careful, you can make sure that this never happens with
functions you've written.  It's harder to have that assurance with
third-party code, however, and being able to use third-party code is
part of what we're trying to accomplish.  We'll address that more in a
bit.

On the other side of the coin, the called function also has a novel
problem.  Access to the global scope is not absolute like in lexical
scoping.  When trying to read or write a global variable, there is no
way to tell whether you've just written to the real global variable, or
a local variable of the same name in a caller's scope.  Depending on the
context of how a function has been called, which itself can vary from
call to call, it may or may not be able to pass information correctly
via global variables.

Reconsider our code above.  *inner_function* had no idea which *lvar* it
was modifying.  If we didn't know about *outer_function*'s use of
*lvar*, we would have thought that we were modifying a global variable
called *lvar* instead.  Depending on whether the variable *lvar* exists
in a caller's scope, we could get two very different outcomes.

{% highlight bash %}
IFS=''
set -o noglob

gvar=one

outer_function () {
  local gvar

  inner_function
  echo "During outer_function is: $gvar"
}

inner_function () {
  gvar=two
}

echo "Global is: $gvar"
outer_function
echo "After outer_function is: $gvar"
inner_function
echo "After inner_function is: $gvar"
{% endhighlight %}

Here we first use a global called *gvar* to store a value.
*outer_function* uses the same name, but protects the global from it
with *local*.  *inner_function* is called and modifies that variable,
first from within *outer_function*, then directly from the global part
of the script.  Based on where it's called, the change affects either
the global variable or the local variable, but *inner_function* can't
tell which one it has modified.  Here's the output:

{% highlight bash %}
Global is: one
During outer_function is: two
# the local variable goes away when the function ends
After outer_function is: one
After inner_function is: two
{% endhighlight %}

Locals Only
-----------

So, it would be nice if you could somehow get bash to use lexical
scoping, but that's not possible.  However, there is at least something
you can do to avoid the pitfalls of dynamic scoping.

The first thing to do is to protect the variables of the functions which
call your function.  The way to do that is to *always* declare your
variables local.  By default, bash assumes any variables you reference
or create are global, and requires you to declare a variable *local* if
you want it so.

Every function I write has a list of these variables right at the top:

{% highlight bash %}
hello_world () {
  local hello_world_text

  hello_world_text="hello, world!"
  echo $hello_world_text
}
{% endhighlight %}

Declaring a variable local means that you'll never change it outside of
your scope by accident, and that when your function ends, the variable
ends with it.  This protects globals and variables in calling scopes.

If you don't do this, you are potentially messing with variables in a
caller's scope, and that makes your code untrustworthy to be reused by
others.

The second thing to do is to protect your local variables from changes
by the functions you call.  How?  Well, there's nothing you can do to
guarantee that.  The only thing you can do is to call code written by
someone who follows the same practices.  Really that's the only thing
you can do, since dynamic scoping simply won't protect your variables
from being messed with.

Continue with [part 21] - data types

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-01-approach-bash-like-a-developer-part-19-disabling-word-splitting  %}
  [lexical scoping]: https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scoping
  [dynamic scoping]: https://en.wikipedia.org/wiki/Scope_(computer_science)#Dynamic_scoping
  [part 21]:      {% post_url 2018-09-02-approach-bash-like-a-developer-part-21-data-types                %}
