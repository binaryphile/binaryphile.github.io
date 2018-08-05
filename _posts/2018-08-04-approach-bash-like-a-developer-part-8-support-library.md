---
layout: post
title:  "Approach Bash Like a Developer - Part 8 - Support Library"
date:   2018-08-04 00:00:00 +0000
categories: bash
---

This is part eight of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we described how to source a library without depending on
PATH. This time we'll look at putting our support function, *sourced*,
in a library and source it from our script.

In the Library, With the Lead Pipe
----------------------------------

Let's extract out our *sourced* function into a support library.  First
we'll need a `lib` directory:

{% highlight bash %}
mkdir lib
{% endhighlight %}

*lib/util.bash:*

{% highlight bash %}
sourced () {
  [[ ${FUNCNAME[1]} == source ]]
}
{% endhighlight %}

Note that there's no shebang for a library file since it's never run as
a command.

*bin/hello_world:*

{% highlight bash %}
#!/usr/bin/env bash

source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/../lib/util.bash

main () {
  hello_world
}

hello_world () {
  echo "hello, world!"
}

sourced && return

main "$@"
{% endhighlight %}

With this arrangement, *hello_world* can focus on what it does without
distraction.

For its part, the support library can supply the same functionality for
all of our projects.  All that is required is a copy of the file and the
*source* statement at the top of the script.

One benefit of this method of sourcing is that you can symlink to
*hello_world* from another location and it will still find the support
library correctly, despite the fact that the link will not share the
same relative position to the library.  That's due to *readlink's*
ability to find the true location of *hello_world*.

Continue with [part 9] - strict mode

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro        %}
  [Last time]:  {% post_url 2018-08-04-approach-bash-like-a-developer-part-7-sourcing     %}
  [part 9]:     {% post_url 2018-08-05-approach-bash-like-a-developer-part-9-another-test %}
