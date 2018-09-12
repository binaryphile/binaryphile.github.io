---
layout: post
title:  "Approach Bash Like a Developer - Part 10 - Test Independence"
date:   2018-08-06 00:00:00 +0000
categories: bash
---

This is part ten of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we factored created a test for our support function,
*sourced*.  This time, I'll discuss the idea of test independence and a
technique for working with shpec.

Independence Day
----------------

The biggest issue with shpec tests is that they all execute in the same
context.

For example, if one test defines a variable, that variable exists for
that test as well as all of the following tests.  Sometimes, a following
test may reuse the same variable name but miss assigning a new value, in
which case the wrong value may get referenced.

It's better for the tests to not share the same function or variable
namespaces.  If they are independent, such a missed assignment would
result in an empty value when referenced instead of a wrong value.

That, however, is still not going to cause the mistake to be caught, at
least in the case of a variable.  An empty value is as bad as a wrong
value.

Unset, Match, Game
------------------

The first thing to do in our test script is to cause unset values to
cause bash to exit with an error message:

{% highlight bash %}
set -o nounset
{% endhighlight %}

While this will cause unset variables to be detected, it will also do
the same for the code under test, which may be undesirable. The solution
is to either make sure the code under test also doesn't try to use unset
variables or to toggle the setting around the function call under test.

The smart choice is to make sure the code under test also doesn't try to
use unset variables if possible.

She Sells Subshells by the Seashore
-----------------------------------

The second thing to do in our test script is to sandbox the body of each
test in a subshell.

A subshell is a new shell context, or rather an entire process, which
is a mirror image of the shell from which it is created.  All of the
functions and variables of the parent shell are in the subshell.

The subshell has no effect on its parent, however, so when it exits, any
changes to variables are gone.  You can't share values from a subshell
back to the parent.  Therefore if all tests are in their own subshell,
they can't affect each others namespaces.

Let's use *hello_world.shpec* as an example:

{% highlight bash %}
describe hello_world
  it "echos 'hello, world!'"
  (
    result=$(hello_world)
    assert equal "hello, world!" "$result"
  )
  end
end
{% endhighlight %}

Subshells are created with parentheses.

This is a fine start, however, it causes issues with shpec.  Shpec
relies on the global variable *_shpec_failures* to keep track of how
many tests have failed.  Because the *assert* function is the one that
modifies the count, and that function must be called in the subshell,
its change to *_shpec_failures* is lost when the subshell ends.

Instead, let's use *_shpec_failures* to count just the errors in the
subshell, then add it to the running count in the parent shell.  All we
need to do is to reset it to zero at the outset, then return it as the
last thing in the subshell and add it in the parent.  Here's the entire
file this time:

{% highlight bash %}
set -o nounset

source "$(dirname "$(readlink -f "$BASH_SOURCE")")"/../bin/hello-world

describe hello_world
  it "echos 'hello, world!'"
  ( _shpec_failures=0
    result=$(hello_world)
    assert equal "hello, world!" "$result"
    return "$_shpec_failures"
  ); ((_shpec_failures += $?))
  end
end
{% endhighlight %}

It's rather ugly looking, but we'll be tidying it up in another post.

Continue with [part 10.5] - aside on aliases

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                %}
  [Last time]:  {% post_url 2018-08-05-approach-bash-like-a-developer-part-9-another-test         %}
  [part 10.5]:  {% post_url 2018-08-23-approach-bash-like-a-developer-part-10.5-aside-on-aliases  %}
