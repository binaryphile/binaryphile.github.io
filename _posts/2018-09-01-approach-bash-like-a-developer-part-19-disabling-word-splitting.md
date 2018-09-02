---
layout: post
title:  "Approach Bash Like a Developer - Part 19 - Disabling Word Splitting"
date:   2018-09-01 00:00:00 +0000
categories: bash
---

This is part nineteen of a series on how to approach bash programming in
a way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed word splitting and why it's not great.
This time, let's disable that sucker.

Let me preface this part with the comment that, like strict mode,
disabling word splitting is something to do in scripts, not at the
command line of your interactive session.

If your *.bashrc* is like mine, you've probably got quite a bit of extra
functionality going on, especially from third-party code.  This stuff is
typically sourced into your current shell, which means it shares the
same settings for global configurations like word splitting.  Turning
off word splitting in the shell will very likely break a lot of those
things.

Emptying Field Separators for Fun and Profit
--------------------------------------------

Unlike many other shell features, word splitting doesn't have a *set* or
*shopt* command to toggle.  Word splitting instead runs off the
*[Internal Field Separator]*, or *IFS*, variable.

I haven't really discussed the *IFS* variable and how it affects word
splitting.  In addition to the above link, you can find a precise, if
dry, description of it [here].

Here's the easy part...to turn off word splitting, just set *IFS*:

{% highlight bash %}
IFS=''
{% endhighlight %}

Notice two things:

-   despite the fact that it is all-capitalized, *IFS* is not an
    environment variable, so you don't export the setting

-   *IFS* needs to be set, but blank

If you unset *IFS*, the shell will provide its default value whenever it
word splits, even though the variable doesn't exist.  That's not what
you want.

If you were to export the blank *IFS*, that would turn off word
splitting for all subprocesses, which is also not what you want.  We
want to control our own environment and not mess up other ones.

Now, there are two things to keep in mind about turning off word
splitting.

Down with Quotes
----------------

The first is that we no longer need to quote our various expansions in
order to allow for whitespace in the results.  That's what I'm talking
about!

For example, let's compare the before and after of our standard line for
sourcing files relative to the current one.

Before:

{% highlight bash %}
source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/../lib/support.bash
{% endhighlight %}

After:

{% highlight bash %}
IFS=''
source $(dirname -- $(readlink --canonicalize -- $BASH_SOURCE))/../lib/support.bash
{% endhighlight %}

Still pretty thorny, but that just means every bit of noise we can
squeeze out counts all the more.

Additionally, now you don't have to think about how quotations nest
inside command substitutions, which can be non-intuitive even (or
especially) to programmers of other languages.

Path Expansion
--------------

The second implication I mentioned has to do with *[path expansion]*, or
*globbing*.

If you followed the standard practice of quoting all of your expansions,
you were also getting protection from this automatic shell feature as
well.

After expansions and word splitting, bash looks for glob expressions and
matches them to files and directories in the current directory,
substituting any results it finds.

That means if you have a value which contains \*, *?* or *[chars]*, then
it will be checked against the filesystem and possibly changed.

For example, this echos "helloa", not "hello?":

{% highlight bash %}
touch helloa
myvar=hello?
echo $myvar
{% endhighlight %}

Inspecting the variable with *declare -p myvar* shows that it indeed has
the question mark in it.  It's the echo command which performs the path
expansion.

Mostly I don't concern myself with this, since the odds are typically
very low that a value I care about also happens to expand to a path.

However, be aware that it happens.  Without going further into detail,
I'll simply recommend that you disable path expansion in your scripts
using *set -o noglob* and only enable it when you need it.

Updated Outline
---------------

Given all of this, here's the updated version of our basic script
outline:

{% highlight bash %}
#!/usr/bin/env bash

IFS=''
set -o noglob

source $(dirname -- $(readlink --canonicalize -- $BASH_SOURCE))/../lib/support.bash

main () {
  hello_world
}

hello_world () {
  echo "hello, world!"
}

sourced && return
strict_mode on

main $@
{% endhighlight %}

Notice the lack of quotation marks in the *source* and *main*
invocations.

We could move the *IFS* and *noglob* settings into the support lib, but
I like it to be explicit in the main script, and also that would require
proper double-quoting on the *source* statement, since that runs before
the support lib is loaded.

Continue with [part 20] - scoping

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-31-approach-bash-like-a-developer-part-18-word-splitting            %}
  [Internal Field Separator]: http://mywiki.wooledge.org/IFS
  [here]:         https://www.gnu.org/software/bash/manual/bashref.html#Word-Splitting
  [path expansion]: http://wiki.bash-hackers.org/syntax/expansion/globs
  [part 20]:      {% post_url 2018-09-01-approach-bash-like-a-developer-part-20-scoping                   %}
