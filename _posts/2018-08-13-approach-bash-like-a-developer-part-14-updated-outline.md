---
layout: post
title:  "Approach Bash Like a Developer - Part 14 - Updated Outline"
date:   2018-08-13 00:00:00 +0000
categories: bash
---

This is part fourteen of a series on how to approach bash programming in
a way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we created a *strict_mode* function.  This time, let's add
it to our outline script.

Here's the *hello-world* outline, with strict mode:

{% highlight bash %}
#!/usr/bin/env bash

# source support.bash
#   or
# source "$(dirname  "$(readlink -f "$BASH_SOURCE")")"/support.bash

main () {
  hello_world
}

hello_world () {
  echo "hello, world!"
}

sourced && return
strict_mode on

main "$@"
{% endhighlight %}

Notice that we turn on strict mode *after* the *sourced && return* line.

This is because strict mode interferes with shpec.  Shpec is looking for
errors and can't have errexit set, or else it will exit without the
*assert* calls having done their job.  If *assert* isn't called, shpec
doesn't output a line for the result of the test.

That's why we use *set -o nounset* at the top of a shpec file and not
the rest of strict mode, since that would include errexit.

The above outline script forms the basis of almost all of the scripts I
write.  However, it's missing one piece...where are *sourced* and
*strict_mode* coming from?

As you can probably guess, I've consolidated all of my support functions
into my own library.  It's called *[concorde.bash]*.  Feel free to take
a look at it and use it for your own projects.

If I have control over the system environment, such as when I write a
script for my own machine, I install my support library in my PATH.
That allows the simple form of sourcing:

{% highlight bash %}
source concorde.bash
{% endhighlight %}

On the other hand, if I don't control the system environment, I
distribute the library with the script and source it using the
*BASH_SOURCE* method you've seen in most of my examples:

{% highlight bash %}
source "$(dirname "$(readlink -f "$BASH_SOURCE")")"/concorde.bash
{% endhighlight %}

Continue with [part 15] - strict mode caveats

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:  {% post_url 2018-08-12-approach-bash-like-a-developer-part-13-implementing-strict-mode  %}
  [concorde.bash]: https://github.com/binaryphile/concorde
  [part 15]:    {% post_url 2018-08-13-approach-bash-like-a-developer-part-15-strict-mode-caveats       %}
