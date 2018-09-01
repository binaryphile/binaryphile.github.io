---
layout: post
title:  "Approach Bash Like a Developer - Part 6 - Outline Script"
date:   2018-07-30 00:00:00 +0000
categories: bash
---

This is part six of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we made our first test succeed. This time we'll put some
finishing touches our source file to better work with shpec. This will
form the outline of a testable script.

Main Street
-----------

While our *hello-world* script has a function, it's not a runnable
script. If you tried to run it, it would do nothing.

Following the tradition of creating a *main* as the entry point to the
logic:

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

The functions are defined at the top, and then main is finally put into
action where it is called at the bottom.  Any script arguments are
handed to main via *"$@"*.

With more sophisticated scripts which take switches and named arguments,
it's acceptable to parse those outside of *main* and pass the processed
values to *main*.

To Run or Not to Run
--------------------

Now that we have a runnable script, our test won't work properly since
it relies on the source file to not actually do anything when we source
it.  Now the script will run *main* when we source it in test, which is
certainly undesirable.

We can make it do the appropriate thing both in test when sourced, as
well as in practice when run, by detecting whether the script has been
sourced:

{% highlight bash %}
#!/usr/bin/env bash

main () {
  hello_world
}

hello_world () {
  echo "hello, world!"
}

[[ $FUNCNAME == source ]] && return

main "$@"
{% endhighlight %}

The *[FUNCNAME]* expression looks at the name of the function which
invoked the script. When bash sources a file, it sets that name to
"source". Otherwise the program is being run as a script.

So if that is true, then the *return* stops the sourcing and returns to
the caller, in this case our shpec test, so that *main "$@"* never gets
run.

Continue with [part 7] - sourcing

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro    %}
  [Last time]:  {% post_url 2018-07-29-approach-bash-like-a-developer-part-5-success  %}
  [FUNCNAME]:   http://wiki.bash-hackers.org/syntax/shellvars#funcname
  [part 7]:     {% post_url 2018-08-04-approach-bash-like-a-developer-part-7-sourcing %}
