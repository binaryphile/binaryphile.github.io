---
layout: post
title:  "Approach Bash Like a Developer - Part 35 - Recursion"
date:   2018-10-29 01:00:00 +0000
categories: bash
---

This is part 35 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed references and indirection. This time, let's
talk about [recursion].

Recursion is a method of structuring a function so that it calls itself
with different parameters to solve a smaller version of the same
problem.  Eventually the problem is small enough to provide a trivial
solution which doesn't require the function to call itself any further,
called a *base-case*.

Recursion relies on the language's built-in frame stack to manage
holding all of the intermediate results without the function needing to
manage them explicitly.

Unfortunately, since bash functions don't return actual values, they
don't have the benefit of a frame stack to manage the return values.

There are a few alternatives:

-   echo results on stdout and use command substitution for recursive
    calls

-   use a global variable for return values

-   use a reference to return a value

The command substitution method is what you see in most discussions of
bash recursion, but it's very slow.  Subshells are expensive, especially
if you end up using a lot of them, which is what the recursive approach
relies on.

Let's do the classic fibonacci example using a reference.

The fibonacci sequence starts with the first two numbers 1 and 1.  Each
term after that is the sum of the prior two terms.  The first several
terms go: 1, 1, 2, 3, 5, 8, 13...

In our case, we're going to consider the sequence to start with 0 and 1,
for reasons you'll see in a bit.  Starting with 0 and 1 doesn't change
the rest of the sequence, so it's fine.

*shpec/fibonacci_shpec.bash:*


{% highlight bash %}
IFS=$'\n'
set -o noglob

Dir=$(dirname $(readlink -f $BASH_SOURCE))/..
source $Dir/lib/shpec-helper.bash
source $Dir/lib/fibonacci.bash

describe fibonacci
  it "calculates 1"
    fibonacci 1 result
    expecteds=( 0 1 )
    assert equal "${expecteds[*]}" "${result[*]}"
  ti

  it "calculates 2"
    fibonacci 2 result
    expecteds=( 0 1 1 )
    assert equal "${expecteds[*]}" "${result[*]}"
  ti

  it "calculates 3"
    fibonacci 3 result
    expecteds=( 0 1 1 2 )
    assert equal "${expecteds[*]}" "${result[*]}"
  ti

  it "calculates 4"
    fibonacci 4 result
    expecteds=( 0 1 1 2 3 )
    assert equal "${expecteds[*]}" "${result[*]}"
  ti

  it "calculates 5"
    fibonacci 5 result
    expecteds=( 0 1 1 2 3 5 )
    assert equal "${expecteds[*]}" "${result[*]}"
  ti
end_describe
{% endhighlight %}

I'm going to do a bit of a trick to make things easier.  The big idea is
to not simply return the requested fibonacci number, it's to return the
entire sequence, from the start.  The requested term will be in the
matching index of the array.

{% highlight bash %}
fibonacci () {
  local term_=$1
  local -n result_=$2
  local -i last_

  (( term_ == 1 )) && {
    result_=( 0 1 )
    return
  }

  last_=term_-1
  fibonacci $last_ $2
  (( result_[term_] = result_[last_] + result_[last_-1] ))
}
{% endhighlight %}

The first part of the function is the base case.  The lowest argument
you can give fibonacci is 1, which tells the function to initialize the
result with 0 and 1 and return it.

Calling fibonacci with the argument 2 goes down the second code path.
Since the result isn't known yet, we call fibonacci again, just with the
argument minus one (which is the base case this time).

The result then has at least two terms (0 and 1), so they can be added
together.  The *result_* array stores the sum in the newest index, which
corresponds to the number of the requested term.

There is one additional wrinkle, which is the question of how the
nameref return variable is able to be used in the recursive call to
*fibonacci*.

Normally, you would supply the call with the name of the reference
variable:

{% highlight bash %}
fibonacci $last_ result_
{% endhighlight %}

However, that results in the warning: *result_: circular name
reference*.  That's because when called, *fibonacci* tries to put the
name *result_* into the following line:

{% highlight bash %}
local -n result_=$2
{% endhighlight %}

Because namerefs can't refer to themselves, it fails.  Fortunately, we
*can* put the original reference name (the one passed by the caller)
into the recursive call instead.  It's still hanging around as *$2*,
which is why the line reads:

{% highlight bash %}
fibonacci $last_ $2
{% endhighlight %}

Memoization
-----------

Since recursion is typically employed to solve computationally complex
problems, it is commonly and mistakenly blamed for being slow.  Rather,
it is typically the problem being solved which is expensive.  Recursion
is simply one technique for solving such a problem.

Unless it can be shown that the recursive technique is slower than other
approaches to solving the same problem, it's wrong to say recursion is
slow.

Nevertheless, once the problem has been solved for a particular input, a
common technique for enhancing performance is [memoization].  Analogous
to, but not to be mistaken for "memorization", memoization is a
technique for storing past results of a function so that it doesn't have
to do as much work when called in the future.  It's the same idea as
caching in that it's trading space (in the array) for time (calculating
terms).

Memoization and recursion frequently go hand-in-hand.  For example, we
could update our *fibonacci* function to test for existing results in
the nameref array and to use them if they exist, rather than recursing.

Unfortunately you can't write unit tests for such a refactoring, since
we aren't changing the interface or what the function returns, just how
it accomplishes its task internally.  Unit tests treat the function as a
black box and don't see how the function does its job.  They test for
correctness, not performance.

So we'll just have to reason it out.  Let's think about whether existing
terms can be used to avoid having to recurse.

{% highlight bash %}
defined? () {
  [[ -v $1 ]]
}

fibonacci () {
  local term_=$1
  local -n result_=$2
  local -i last_

  (( term_ == 1 )) && {
    result_=( 0 1 )
    return
  }

  last_=term_-1
  ! defined? result_[$last_] && fibonacci $last_ $2   # changed
  (( result_[term_] = result_[last_] + result_[last_-1] ))
}
{% endhighlight %}

Here, the last term is checked for before calling *fibonacci* again.  If
it exists, then we can be assured that the term before it exists as
well, and therefore can add the last two terms, skipping the call.

Conversely, if the last term doesn't exist, the simplest way to get it
is to make the recursive call, at which point we know we can add the
terms in the result.

When we want to take advantage of memoization now, all we need to do is
call *fibonacci* with the array that we obtained from a prior
*fibonacci* call.  If so, it will not have to recurse for any of the
terms which already exist in the array.

That's it, recursion with memoization.  The beautiful thing about
recursion is that when done properly, it usually results in simple code.
It is a divide-and-conquer approach that decomposes complex problems
into simpler ones which are more easily solved.  On problems suited to
the approach, it can be very powerful as well as performant.  There is
nothing inherently slow about it, unless you use a technique such as
subshells, which make function calls extremely expensive.

Continue with [part 36] - functional programming

  [part 1]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
  [Last time]: {% post_url 2018-10-28-approach-bash-like-a-developer-part-34-indirection %}
  [recursion]: https://en.wikipedia.org/wiki/Recursion_(computer_science)
  [memoization]: https://en.wikipedia.org/wiki/Memoization
  [part 36]: {% post_url 2018-10-31-approach-bash-like-a-developer-part-36-functional-programming %}
