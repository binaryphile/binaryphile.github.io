---
layout: post
title:  "Approach Bash Like a Developer - Part 25 - Passing Hashes"
date:   2018-09-18 01:00:00 +0000
categories: bash
---

This is part 25 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed passing arrays as arguments to functions.
This time, let's discuss passing hashes instead.

While we were able to find a relatively convenient method of serializing
and deserializing arrays by using the ascii unit separator along with
the splat expansion and the *local* command, the same can't be done for
hashes.

The *local* trick is problematic because it's difficult to turn a hash
into a hash literal without writing code to do it.  And, unfortunately,
that's about the size of it.  We're going to have to write code if we
want to find a way to serialize a hash easily.

So what are we waiting for?  Let's write a test using our template:

{% highlight bash %}
IFS=$'\037'
set -o noglob
set -o nounset
shopt -s expand_aliases
alias it='(_shpec_failures=0; alias setup &>/dev/null && { setup; unalias setup; alias teardown &>/dev/null && trap teardown EXIT ;}; it'
alias ti='return $_shpec_failures); (( _shpec_failures += $?, _shpec_examples++ ))'
alias end_describe='end; unalias setup teardown &>/dev/null'

source $(dirname $(readlink -f $BASH_SOURCE))/../lib/support.bash

describe rep
  it "generates a representation of a hash"
    declare -A samples=(
      [zero]=0
      [one]=1
    )
    result=$(rep samples)
    assert equal '([one]="1" [zero]="0" )' $result
  ti
end_describe
{% endhighlight %}

The idea here is to take the *declare -p* output and trim off the first
part of the declaration, the part in which the variable name appears.
I'll go straight to the working version:

{% highlight bash %}
rep () {
  local rep_

  rep_=$(declare -p $1)
  rep_=${rep_#*\'}
  echo ${rep_%\'}
}
{% endhighlight %}

Here is how it's used:

{% highlight bash %}
myfunc () {
  local -A myhash=$1

  # inspect the result to see that it worked
  declare -p myhash
}

declare -A argument=([zero]=0)

myfunc $(rep argument)
{% endhighlight %}

While this isn't as clean as the array passing in the last post, this is
the cleanest I can get it while still passing by value.  As compared to
the array passing, there's an additional call to *rep* in order to feed
*myfunc*.  Unfortunately that seems unavoidable.

At least the implementation of *rep* is simple, thanks to *declare -p*.
In fact, since we're using *declare*, *rep* isn't even specific to
hashes...if you like this method better than the array-passing method,
it works for arrays as well if you just change the *local -A* to *local
-a*.  In fact, it also gets around the sparse array issue since *declare
-p* provides the correct indexes.

Continue with [part 26] - returning values

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-16-approach-bash-like-a-developer-part-24-passing-arrays            %}
  [part 26]:      {% post_url 2018-09-22-approach-bash-like-a-developer-part-26-returning-values          %}
