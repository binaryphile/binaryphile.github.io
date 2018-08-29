---
layout: post
title:  "Approach Bash Like a Developer - Part 16 - Recap"
date:   2018-08-24 00:00:00 +0000
categories: bash
---

This is part sixteen of a series on how to approach bash programming in
a way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we wrapped up talking about strict mode caveats.  This
time, let's reflect on where we are.

Mirror, Mirror
--------------

We've learned about:

-   vim and the various ways to start a script

-   writing unit tests with shpec and coming up with a template for
    tests

-   writing a script which can either be run or be tested depending on
    how it's accessed

-   sourcing files relative to our script's true location

-   factoring functions into a separate library

-   developing with strict mode and the caveats involved

-   coming up with a template script which incorporates all of the above

This is a pretty solid start for getting a new bash developer off on the
right foot.  Testable code is code with fewer surprises, which is
especially useful in a frequently surprising language such as bash.

What Next
---------

There are many details to explore with bash, and further challenges to
developing software with it.

I'd like to discuss some basic techniques that you should be aware of in
any script, with a focus on making reliable and safe code.

I'd also like to highlight practices which will enhance your ability to
write reusable code and compose more complicated pieces of
functionality.

I'd like to develop some new functionality which makes the bash
environment more amenable to writing software from reusable components.

Finally, I'd like to discuss a grab-bag of standard programming
techniques, such as recursion, and how best to approach them given what
we've learned and accomplished.

This means discussing:

-   command processing

-   well-known gotchas

-   finessing bash syntax

-   data types and scoping

-   passing arguments and receiving return values

-   debugging

-   traps and tracebacks

-   parsing options

-   creating modules

-   indirection

-   recursion

-   light functional programming

As I certainly haven't learned everything there is to know about each of
these topics, tests will form the foundation of truth for all of my
work.

I hope to illustrate each major point with a small set of simple tests,
from which you can go more deeply on your own.  The key is to become
comfortable expressing requirements in tests, which is how a developer
(or rather, this developer) approaches bash.

Anything I do wrong should fail, and any reader who finds a mistake in
my work should be able to write a test to show what it fails to reflect.

Continue with [part 17] - command processing

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-13-approach-bash-like-a-developer-part-15-strict-mode-caveats       %}
  [part 17]:      {% post_url 2018-08-25-approach-bash-like-a-developer-part-17-command-processing        %}