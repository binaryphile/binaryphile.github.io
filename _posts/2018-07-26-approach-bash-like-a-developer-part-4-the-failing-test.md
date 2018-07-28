---
layout: post
title:  "Approach Bash Like a Developer - Part 4 - The Failing Test"
date:   2018-07-28 00:00:00 +0000
categories: bash
---

This is part four of a series on how to approach bash programming in a
way that's safer and more structured than your basic script, as taught
by most tutorials.

Pass the Test
-------------

Do you write tests? I'll presume that you do. That's mostly what the
"Like a Developer" portion of the series title implies.

If you don't, please go ahead and read some resources on [Test-First
Design] or [Test-Driven Design].

My personal opinion is that TDD is a very time-intensive, and therefore
expensive, way to design software. While I have yet to see evidence that
it results in software which is more correct at release-time than other
methods, I can testify that it results in software which is much more
maintainable and enhanceable at lower cost than other methods.

Is it the right way for you to work? I don't presume to say so. I use it
when appropriate. For work product, I don't always use it because
maintainance costs are not always at a premium and I write a lot of
one-and-done tasks. It is certainly legitimate to write post-hoc or
minimal tests. When its necessary to refactor or enhance code, it's
certainly possible, although difficult, to write tests at that point,
using TDD forward from there once its need has been proven on a
particular task.

That said, for my personal projects, I try to use it 100%.

A Framework for Peace (of Mind)
-------------------------------

Usually TDD is accomplished with the help of tools specific to the
chosen language, and bash is no different.

Believe it or not, there are numerous choices of testing frameworks for
bash. For a full list, you can see [one of the "awesome shell" lists] I
recommended in [part 1] of this series. While I haven't compared them
all, I'm most comfortable with [shpec].  Shpec is the most like the
rspec testing to which I'm accustomed.

I'll be using v2.2.0 of shpec for my examples here.

Quick shpec installation:

{% highlight bash %}
git clone --branch=0.2.2 --depth=1 git://github.com/rylnd/shpec
PATH+=:$PWD/shpec/bin
{% endhighlight %}

You'll want to choose your own installation location and add it to your
path in your `.bashrc` (or similar) for permanent installation.

Fail Whale
----------

The first thing to do in test-first design is to fail. I'll start with a
simple test, and in further posts will build up to the point where we
are passing.

The first difference between the developer's approach and the scripting
approach is to rely on functions.  Functions allow us to create small,
testable, descriptively-named pieces of functionality.

The use of functions is typically justified as a means to effect code
reuse.  Code reuse is fine and all, but that's less the point here.
Testability is what we care about first and foremost, and testing
requires the ability to call a function in, essentially, a vacuum.  So
we'll focus on functions here.

To begin with, shpec uses a begin-end format to specify which function
is currently under test, and to specify the test subject matter.

{% highlight bash %}
describe hello_world
  it "says 'hello, world!'"
    result=$(hello_world)
    assert equal "hello, world!" "$result"
  end
end
{% endhighlight %}

The indentation on the above test is rather artificial...the *describe*
and *it* blocks aren't really blocks, they are just regualar bash
statements. However, it is a useful visual reminder to indent this way
to remember where things begin and end.

Let's call the above file `hello-world_shpec.bash`, since the file we'll
be developing will be called `hello-world`. Here's the output from a
shpec run on this test file:

{% highlight bash %}
> shpec hello-world_shpec.bash
hello_world
hello-world_shpec.bash: line 3: hello_world: command not found
  echos 'hello, world!'
  (Expected [hello, world!] to equal [])
1 examples, 1 failures
0m0.000s 0m0.000s
0m0.000s 0m0.000s
{% endhighlight %}

Failure. Excellent!

The output starts with "hello\_world", which is the subject of the
*describe* call.

Next is an error thrown by the script, "command not found".  This is not
part of the shpec output.

The results for the *it* claus is next, indented.  It shows the
description of the *it* ("echos 'hello, world!'").

If the call had succeeded, that would be the end of it.  Since it failed,
however, you see a comparison of the expected value to what the test
received from the function call.

After that, there is a summary showing the number of tests, called
"examples", and the number of failures.

Following that, there's a measure of the time of execution.

As you can see, the test had problems both finding the function as well
as getting the expected value in the assertion.

Continue with [part 5] - red, green, refactor.

  [Test-First Design]: http://wiki.c2.com/?TestFirstDesign
  [Test-Driven Design]: http://agiledata.org/essays/tdd.html
  [one of the "awesome shell" lists]: https://github.com/alebcay/awesome-shell
  [part 1]: %7B%%20post_url%202018-07-26-approach-bash-like-a-developer-part-1-intro%20%%7D
  [shpec]: https://github.com/rylnd/shpec
