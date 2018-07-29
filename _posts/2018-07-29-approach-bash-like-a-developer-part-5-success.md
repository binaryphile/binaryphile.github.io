---
layout: post
title:  "Approach Bash Like a Developer - Part 5 - Success!"
date:   2018-07-29 00:00:00 +0000
categories: bash
---

This is part five of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we created a failing test. We'll work on making it work
now, but I'm going to jump straight to the structure that a project with
tests should take.

The project will be a *hello, world!* script, so let's start with:

{% highlight bash %}
mkdir hello-world
cd hello-world
mkdir bin
mkdir shpec
echo '#!/usr/bin/env bash' >bin/hello-world
echo 'hello_world () { :;}' >>bin/hello-world
chmod 775 bin/hello-world
{% endhighlight %}

The *hello\_world* function exists, but does nothing.

Move `hello-world_shpec.bash` to the `shpec` directory.

Open `hello-world_shpec.bash` in an editor and add the following to the
beginning:

{% highlight bash %}
source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/../bin/hello-world
{% endhighlight %}

That finds the true location of the `hello-world_shpec.bash` via
`readlink`, then trims off the filename from the path. It then adds the
relative path to our `hello-world` source file.

Note that on Mac, you'll need to install GNU readlink via homebrew, then
use `greadlink` instead of the `readlink` above.

Shpec now outputs the following:

{% highlight bash %}
> shpec shpec/hello-world_shpec.bash
hello_world
  echos 'hello, world!'
  (Expected [hello, world!] to equal [])
1 examples, 1 failures
0m0.004s 0m0.000s
0m0.000s 0m0.000s
{% endhighlight %}

Still failing.  Excellent!

At this point, all we need to do is update the *hello_world* function:

{% highlight bash %}
#!/usr/bin/env bash

hello_world () {
  echo "hello, world!"
}
{% endhighlight %}

Shpec's output:

{% highlight bash %}
> shpec shpec/hello-world_shpec.bash
hello_world
  echos 'hello, world!'
1 examples, 0 failures
0m0.000s 0m0.000s
0m0.000s 0m0.000s
{% endhighlight %}

Success! Excellent!

Continue with [part 6] - polishing up testing

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro            %}
  [Last time]:  {% post_url 2018-07-28-approach-bash-like-a-developer-part-4-the-failing-test %}
