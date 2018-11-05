---
layout: post
title:  "Approach Bash Like a Developer - Part 36 - Functional Programming"
date:   2018-10-31 01:00:00 +0000
categories: bash
---

This is part 36 and the last of a series on how to approach bash
programming in a way that's safer and more structured than your basic
script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed recursion and memoization. This time, let's
talk about [functional programming], or fp.

Functional programming is a philosophy that centers around immutability,
functions as first-class entities and deterministic results for given
inputs to functions.  Long story short, it's way more than I'm ready to
explore, especially with a language like bash.

If you want to learn a bit more about functional principles, here's a
good [blog entry] on the basics.

That said, there are a few tools which are popularly borrowed from
fp by non-functional languages.  In particular, most languages implement
the following list-oriented functions:

-   *map* - iterate over an array of items, applying a unary function to
    each item and returning the results in a new array

-   *filter* - a.k.a. *select*, iterate over an array, applying a unary
    function, returning items for which the function returns true in a
    new array

-   *reduce* - a.k.a. *fold*, iterate over an array of items, applying a
    binary function to an accumulator and each term, returning the
    result from the accumulator

You can find plenty of implementations of these and more for bash.
Let's learn a little bit about how we might implement these ourselves.

Map
---

There are two ways we could approach the input to *map*.  We could
either accept an array or operate on a stream on stdin.

Ideally, we'd be able to do both, but for our purposes I'm going to
choose the stream method so we can easily pipeline functions together,
which is a hallmark of these tools.

*shpec/fp_shpec.bash:*

{% highlight bash %}
IFS=$'\n'
set -o noglob

Dir=$(dirname $(readlink -f $BASH_SOURCE))/..
source $Dir/lib/shpec-helper.bash
source $Dir/lib/fp.bash

describe map
  it "uppercases text"
    uppercase () { echo ${1^} ;}
    strings=( zero one )
    result=$(echo "${strings[*]}" | map uppercase)
    expecteds=( Zero One )
    assert equal "${expecteds[*]}" "${result[*]}"
  ti
end_describe
{% endhighlight %}

Here we're feeding some items to the *uppercase* function we've created
for this purpose.  The only argument that *map* requires is the name of
the function that it will apply to the terms.  It takes its input from
the pipeline.  In this case, that's two strings.

Since we're dealing with a pipeline, the result has to be on stdout.
We're capturing it with command substitution here so we can validate
it against the expected result.

*lib/fp.bash:*

{% highlight bash %}
map () {
  local function_to_apply=$1
  local arg

  while read -r arg; do
    $function_to_apply $arg
  done;:
}
{% endhighlight %}

Fortunately, bash makes this easy.  We've already seen the streaming
read pattern in a number of my earlier posts.  The while loop continues
line by line so long as there is input to be had.

Each time, *map* applies whatever function was requested to the current
argument.  Even though the function to apply is provided as a string,
bash expands the argument before attempting to run the command.  No eval
nor other magic is required.

Map with a Lambda
-----------------

Anonymous functions, or "lambdas", are another typical feature of
functional programming.  Lambdas are functions which don't have a name
assigned to them.  They are typically passed as arguments to other
functions.

Most languages allow full-featured functions as lambdas, although others
only allow limited expressions.  We'll be doing a little bit of both,
but I'll call them expressions because that's what they'll be in bash.
Don't worry though, you can actually have full-fledged functions in the
bargain because of bash's command substitution capability.

We'll start with just a lambda expression which evaluates to a string.

{% highlight bash %}
it "takes a lambda"
  strings=( zero one )
  result=$(echo "${strings[*]}" | map '${1^}')
  expecteds=( Zero One )
  assert equal "${expecteds[*]}" "${result[*]}"
ti
{% endhighlight %}

We're reproducing the same test case as the *uppercase* one, just with a
lambda expression this time.  We'll evaluate the lambda as a string
expression and echo it on stdout.

{% highlight bash %}
map () {
  local function_to_apply=$1
  local arg

  while read -r arg; do
    ! [[ $function_to_apply == *\$* ]]
    case $? in
      0 ) $function_to_apply $arg;;
      * )
        set -- $arg
        eval "echo $function_to_apply"
        ;;
    esac
  done;:
}
{% endhighlight %}

Here we've just added the test for *$* in the function string.  If it's
not supplied, we do the same as before.  Any expression which is a
lambda will need to contain a *$* somewhere, as we'll see.

If it is present, we instead turn the *read* argument into the
positional argument *$1* with *`set --`*.  Then we evaluate the function
string, and add an *echo* to put the result on stdout.

An expression is great, but if we want the full capability of a
function, we'll need something else.  Fortunately, bash provides a means
for evaluating a command in a string context...command substitution.

{% highlight bash %}
it "takes a command substitution"
  strings=( zero one )
  result=$(echo "${strings[*]}" | map '$(echo ${1^})')
  expecteds=( Zero One )
  assert equal "${expecteds[*]}" "${result[*]}"
ti
{% endhighlight %}

This test passes with our existing implementation.  Notice that the
expression has a dollar-sign leading it off.

In addition, since the command substitution takes place in a subshell,
you can do things like set shell settings or change variables such as
*IFS* without having to reset them, since they won't affect the parent
shell.  That can make lambda expressions shorter and easier to use
instead of full function definitions.

Finally, let's look at a mathematical expression.

{% highlight bash %}
it "takes an arithmetic substitution"
  integers=( 1 2 )
  result=$(echo "${integers[*]}" | map '$(( $1*2 ))')
  expecteds=( 2 4 )
  assert equal "${expecteds[*]}" "${result[*]}"
ti
{% endhighlight %}

This also passes since arithmetic expansion is another form of string
expression.  Notice again it also starts with a *$*, so we're covered
with the difference between a function name and lambda.

*map* is the most straightforward of the three.  Let's look at filter
next.

Filter
------

*filter* takes a boolean function and returns the items of the input
array for which the function returns true.

{% highlight bash %}
describe filter
  it "returns evens"
    even? () { (( $1 % 2 == 0 )) ;}
    integers=( 1 2 3 4 )
    result=$(echo "${integers[*]}" | filter even?)
    expecteds=( 2 4 )
    assert equal "${expecteds[*]}" "$result"
  ti
end_describe
{% endhighlight %}

Here we define a test for even numbers, then employ filter with it on a
few integers, expecting the evens back.

{% highlight bash %}
filter () {
  local function_to_apply=$1
  local arg

  while read -r arg; do
    $function_to_apply $arg && echo $arg
  done;:
}
{% endhighlight %}

Much the same as map, we invoke the function with the argument, only
this time if it results in true, then we echo the argument on stdout.

{% highlight bash %}
it "allows a lambda"
  integers=( 1 2 3 4 )
  result=$(echo "${integers[*]}" | filter '(( $1 % 2 == 0 ))')
  expecteds=( 2 4 )
  assert equal "${expecteds[*]}" "$result"
ti
{% endhighlight %}

Here's a test for a lambda expression.

{% highlight bash %}
filter () {
  local function_to_apply=$1
  local arg

  while read -r arg; do
    ! [[ $function_to_apply == *\$* ]]
    case $? in
      0 ) $function_to_apply $arg && echo $arg;;
      * )
        set -- $arg
        eval "$function_to_apply && echo $1"
        ;;
    esac
  done;:
}
{% endhighlight %}

Not much to explain here.  We've just changed the eval from *map* to
evaluate the function then use the result to decide to echo the
argument.

Last, let's do *reduce*.

Reduce
------

Reduce is an accumulation function.  It takes an initial value for an
accumulator, then iterates over an array.  It takes a binary
(two-argument) function and applies it to each array item along with the
current value of the accumulator, accumulator first.

A simple example is string concatenation.

{% highlight bash %}
describe reduce
  it "concatenates strings"
    concatenate () { echo $1+$2 ;}
    strings=( one two )
    result=$(echo "${strings[*]}" | reduce concatenate zero)
    assert equal zero+one+two $result
  ti
end_describe
{% endhighlight %}

The accumulator needs an initializer, as it isn't normally part of the
sequence.  It's typically initialized to what's considered an identity
value for the kind of operation the function represesents.  For things
like multiplication, that's the number 1.  For addition, it's the number
0.

{% highlight bash %}
reduce () {
  local function_to_apply=$1
  local accumulator=$2
  local arg

  while read -r arg; do
    accumulator=$($function_to_apply $accumulator $arg)
  done;:
  echo $accumulator
}
{% endhighlight %}

This is a bit different because we're only returning one value.  Instead
of echoing each time through the loop, we capture the result in the
accumulator and feed it to the function once more.  There are more
efficient ways to do this, but we're going for clarity here.

Alternatively, you can leave out an initial value for the accumulator,
in which case the function can take the first element of the array as
its initial value.  We'll get to that next.

{% highlight bash %}
it "concatenates strings without an initial value for the accumulator"
  concatenate () { echo $1+$2 ;}
  strings=( zero one two )
  result=$(echo "${strings[*]}" | reduce concatenate)
  assert equal zero+one+two $result
ti
{% endhighlight %}

Nothing surprising here, just the same test minus the initializer.

{% highlight bash %}
reduce () {
  local function_to_apply=$1
  local accumulator=${2:-}                # changed
  local arg

  (( $# == 1 )) && read -r accumulator    # new
  while read -r arg; do
    accumulator=$($function_to_apply $accumulator $arg)
  done
  echo $accumulator
}
{% endhighlight %}

For our last trick, we'll use a lambda.

{% highlight bash %}
it "concatenates strings with a lambda"
  strings=( one two )
  result=$(echo "${strings[*]}" | reduce '$1+$2' zero)
  assert equal zero+one+two $result
ti

it "concatenates strings with a lambda without an initializer"
  strings=( zero one two )
  result=$(echo "${strings[*]}" | reduce '$1+$2')
  assert equal zero+one+two $result
ti
{% endhighlight %}

One test for each initializer style.

{% highlight bash %}
reduce () {
  local function_to_apply=$1
  local accumulator=${2:-}
  local arg

  (( $# == 1 )) && read -r accumulator
  while read -r arg; do
    ! [[ $function_to_apply == *\$* ]]
    case $? in
      0 ) accumulator=$($function_to_apply $accumulator $arg);;
      * )
        set -- $accumulator $arg
        eval "accumulator=\$(echo $function_to_apply)"
        ;;
    esac
  done
  echo $accumulator
}
{% endhighlight %}

I think I'll leave this last analysis up to you.  If you've made it this
far through the entire series, you're certainly up to it by now.

Congratulations, you've approached bash like a developer.  Happy
bashing!

  [part 1]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
  [Last time]: {% post_url 2018-10-29-approach-bash-like-a-developer-part-35-recursion %}
  [functional programming]: https://en.wikipedia.org/wiki/Functional_programming
  [blog entry]: https://medium.com/@cscalfani/so-you-want-to-be-a-functional-programmer-part-1-1f15e387e536
