---
layout: post
title:  "Approach Bash Like a Developer - Part 20 - Scoping"
date:   2018-09-01 01:00:00 +0000
categories: bash
---

This is part twenty of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we disabled path expansion.  This time, let's discuss
variable scoping.

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
operates on the *lvar* in the closest enclosing *runtime* scope, which
belongs to *outer_function*.  As a result, *outer_function*'s *lvar* is
changed to "two", and that's what *outer_function* echos.

If you're careful, you can make sure that your code never modifies the
variables of functions which call it.  It's harder to have that
assurance with third-party code, however, and being able to use
third-party code is part of what we're trying to accomplish.  We'll
address that more in a bit.

On the other side of the coin, the called function also has a novel
problem.  Access to the global scope is not absolute like in lexical
scoping.  When trying to read or write a global variable, there is no
way to tell whether you've just written to the real global variable, or
a local variable of the same name in a caller's scope.  Depending on how
a function has been called, which may vary from call to call, you may
not be able to pass values correctly via global variables.

Reconsider our code above.  *inner_function* had no idea which *lvar* it
was modifying.  If we didn't know about *outer_function*'s use of
*lvar*, we would have thought that we were modifying a global variable
called *lvar* instead.  Depending on whether the variable *lvar* exists
in a caller's scope, we could get two very different outcomes.

Technically speaking, however, that isn't 100% true.  You *can* enforce
assigning values to the global scope with the *declare -g myvar=myvalue*
statement.

You cannot, however, enforce the reading of a variable from the global
scope, so *declare -g*'s use is limited.  For example, you can use it
ensure that the value you are returning from a function via a global
variable actually makes it to the global scope, but that's about it.

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
  local text

  text="hello, world!"
  echo $text
}
{% endhighlight %}

Declaring a variable local means that you'll never change it outside of
your scope by accident, and that when your function ends, the variable
ends with it.

The second thing to do would be to protect your local variables from
changes by the functions you call.

How?  Unfortunately it can't be guaranteed.  You can only do the next
best thing, which is to make sure the code you call was authored by
someone who follows the same practices you do.

Continue with [part 21] - environment variables

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-09-approach-bash-like-a-developer-part-19.5-disabling-path-expansion  %}
  [lexical scoping]: https://en.wikipedia.org/wiki/Scope_(computer_science)#Lexical_scoping
  [dynamic scoping]: https://en.wikipedia.org/wiki/Scope_(computer_science)#Dynamic_scoping
  [part 21]:      {% post_url 2018-09-02-approach-bash-like-a-developer-part-21-environment-variables     %}
