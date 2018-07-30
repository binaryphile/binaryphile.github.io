---
layout: post
title:  "Approach Bash Like a Developer - Part 6 - Polishing Up"
date:   2018-07-30 00:00:00 +0000
categories: bash
---

This is part six of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we made our first test succeed. This time we'll put some
finishing touches on the source and test files. This will form the
template for how I write tests for the rest of the series.

Main Street
-----------

While our *hello-world* script has a function, it's not a runnable
script. If you tried to run it, it would do nothing.

I follow the tradition of creating a *main* as the entry point to the
logic in my scripts:

{% highlight bash %}
#!/usr/bin/env bash

main () {
  hello_world
}

hello_world () {
  echo "hello, world!"
}

main "$@"
{% endhighlight %}

I follow the boilerplate practice of handing any script arguments to
main with `"$@"`.

With more sophisticated scripts which take switches and named arguments,
I typically parse those outside of *main* and pass the processed values
to *main*.

To Run or Not to Run
--------------------

Now that we have a runnable script, our test won't work properly since
it relies on the source file not doing anything but offering a set of
functions. Now the script will be run when we source it in test, which
is certainly undesirable.

We can make it work in both situations by detecting whether the script
has been sourced:

{% highlight bash %}
#!/usr/bin/env bash

main () {
  hello_world
}

hello_world () {
  echo "hello, world!"
}

sourced () {
  [[ ${FUNCNAME[1]} == source ]]
}

sourced && return

main "$@"
{% endhighlight %}

Although it looks a bit strange to create a *sourced* function for a
single use right afterward, as you can probably guess, I stick this
function in a library and use it in almost every script.

The *sourced* function simply looks at the name of the function which
called the script. When bash sources a file, it sets that name to
"source". Otherwise the program is being run as a script.

If true, then the `sourced && return` statement stops the sourcing and
returns to the caller, in this case our shpec test, so that `main "$@"`
never gets run.

You'll note that I frequently prefer *&&* to an *if..then* statement.

Continue with [part 7]

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro    %}
  [Last time]:  {% post_url 2018-07-29-approach-bash-like-a-developer-part-5-success  %}
