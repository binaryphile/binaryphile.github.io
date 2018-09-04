---
layout: post
title:  "Approach Bash Like a Developer - Part 10.5 - Aside on Aliases"
date:   2018-08-23 00:00:00 +0000
categories: bash
---

This is part ten and a half of a series on how to approach bash
programming in a way that's safer and more structured than your basic
script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed the concept of test independence and using
subshells to sandbox namespaces.  This time, I'll do a brief aside on
aliases, which will help us tidy up our test outline.

TL;DR
-----

The goal of this post is to support everything we discussed in the last
post, while removing some of the clutter.

The final result for one of our tests will look like this:

{% highlight bash %}
describe hello_world
  it "echos 'hello, world!'"
    result=$(hello_world)
    assert equal "hello, world!" "$result"
  ti
end
{% endhighlight %}

Notice that the subshell notation has disappeared.  Also, the *end* call
for the *it* block has been replaced by *ti*.  However, the subshell is
still there, as well as the *_shpec_failures* management.

The magic is accomplished with the help of the following alias code:

{% highlight bash %}
shopt -s expand_aliases
alias it='(_shpec_failures=0; it'
alias ti='return "$_shpec_failures"); (( _shpec_failures += $?, _shpec_examples++ ))'
{% endhighlight %}

When bash runs the above test, it first rewrites the code with the
substitutions above.

While it's morally equivalent to the earlier version of the test, there
is one change. With the alias, the string argument to the *it* call has
to come last, forcing *it* to move inside the subshell.  *it* and *end*
manipulate some of shpec's internal variables, which are lost when the
subshell ends.  *_shpec_failures* was already dealt with, but
*_shpec_examples* needs to be incremented as well, so it has been added
to the closing alias.  We also don't need the *end* call at all since
its changes are lost.

Also Known As
-------------

Aliases are one way of creating something like a mini-function in bash.
Supposedly bash supported aliases prior even to supporting functions
themselves, so they've been around for a while.

Usually you see them in *.bashrc* configurations for interactive use,
and alias support is disabled by default for non-interactive use such as
scripts.  That is why you need to turn them on with *shopt -s
expand_aliases*.

However, they aren't functions.  They aren't declared in the function
namespace and they don't get their own local variable scope or
positional arguments.

Aliases are more like preprocessor macros in C.  When the bash parser
encounters a new command, it first checks to see whether the command is
an alias.  If so, it edits the line to actually substitute the alias
text in-place before reparsing it.

Conventional wisdom is that functions completely supplant aliases, and I
do prefer them for their flexibility, but aliases do have some clever
and unique uses which functions simply can't replicate, as we have just
seen.

Nothing Up Our Sleeve
---------------------

Because it is manipulating the source code before the source code is
actually evaluated, an alias can do important things which a function
cannot.

For our purpose, it's the creation and termination of a subshell.  With
the exception of overlapping variable names, functions generally can't
affect the context of the caller.  Since an alias never changes context
from its caller, and because it's injected before evaluation, tokens
like parentheses can be added as they are above.  A function is
incapable of accomplishing the same effect.

By the same virtue, there are other potentially useful applications of
aliases in bash, but having cleaned up our test code is enough for this
aside.

Actually, One More Thing Up Our Sleeve
--------------------------------------

Before wrapping up, however, let's add one more feature.  Shpec doesn't
have setup or teardown functions which can be automatically invoked by
the framework to do some prep for tests which need it.

For example, some tests I write need to work with files.  For these I
usually create a temporary file or directory which I remove when the
test is complete.  Here's another version of the aliases which allows me
to specify a setup and teardown aliases within a *describe* block which
are invoked around each *it* case:

{% highlight bash %}
shopt -s expand_aliases
alias it='(_shpec_failures=0; alias setup &>/dev/null && { setup; unalias setup; alias teardown &>/dev/null && trap teardown EXIT ;}; it'
alias ti='return "$_shpec_failures"); (( _shpec_failures += $?, _shpec_examples++ ))'
alias end_describe='end; unalias setup teardown 2>/dev/null'
{% endhighlight %}

These changes invoke *setup* and *teardown*, if they are defined, to run
at the appropriate time.  Note that they are run within the subshell
context, so variables will not remain between tests, preserving test
independence.

They are unaliased at the end of a *describe* block by replacing *end*
with the new *end_describe*.  An example in practice might look like so:

{% highlight bash %}
describe hello_file
  alias setup='file=$(mktemp) || return'
  alias teardown='rm "$file"'

  it "writes 'hello, world!' to a file"
    hello_file "$file"
    assert equal "hello, world!" "$(<"$file")"
  ti
end_describe
{% endhighlight %}

Over many examples, this can save a lot of boilerplate code since the
setup and teardown will be handled automatically for every *it* block.

Continue with [part 11] - strict mode

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro              %}
  [Last time]:  {% post_url 2018-08-06-approach-bash-like-a-developer-part-10-test-independence %}
  [part 11]:    {% post_url 2018-08-09-approach-bash-like-a-developer-part-11-strict-mode       %}
