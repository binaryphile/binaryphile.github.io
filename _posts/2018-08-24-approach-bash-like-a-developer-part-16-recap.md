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

We'll discuss some basic techniques that you should be aware of in any
script, with a focus on making reliable and safe code.

I'll highlight practices which will enhance your ability to write
reusable code and compose more complicated pieces of functionality.

We'll develop some new functionality which makes the bash environment
more amenable to writing software from reusable components.

And finally, I'll discuss a grab-bag of standard programming techniques,
such as recursion, and how best to approach them given what we've
learned.

This means discussing:

-   command processing

-   gotchas

    -   word splitting

    -   path expansion

    -   scoping

-   data types

-   passing arguments

-   receiving return values

-   traps and tracebacks

-   debugging

-   option parsing

-   parallelism

-   modules

-   indirection

-   recursion

-   light functional programming

Continue with [part 17] - command processing

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-13-approach-bash-like-a-developer-part-15-strict-mode-caveats       %}
  [part 17]:      {% post_url 2018-08-25-approach-bash-like-a-developer-part-17-command-processing        %}
