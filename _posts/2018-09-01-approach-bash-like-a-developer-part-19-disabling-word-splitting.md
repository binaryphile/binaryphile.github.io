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

-   *IFS* needs to be set, but empty

If you unset *IFS*, the shell will provide its default value whenever it
word splits, even though the variable doesn't exist.  That's not what
you want.

If you were to export the empty *IFS*, that would turn off word
splitting for all subprocesses, which is also not what you want.  We
want to control our own environment and not mess up other ones.

*Note:* I'll have reason later to fuss with *IFS* more, so this isn't
the final word.  But for now, let's keep things simple and disable it.

Now, there are two things to keep in mind about turning off word
splitting.

Down with Quotes
----------------

The first is that we no longer need to quote our various expansions.
That's what I'm talkin' about!

For example, let's compare the before and after of our standard line for
sourcing files relative to the current one.

Before:

{% highlight bash %}
source "$(dirname "$(readlink -f "$BASH_SOURCE")")"/../lib/support.bash
{% endhighlight %}

After:

{% highlight bash %}
IFS=''
source $(dirname $(readlink -f $BASH_SOURCE))/../lib/support.bash
{% endhighlight %}

It still won't win any beauty contests, but that just means every bit of
noise we can squeeze out counts all the more.

An Exception
------------

There are two special parameter expansions which are affected by the
disabling of word splitting.

The first is the `"$*"` expansion, which is one of the [splat]
expansions.  (the other is using a splat to expand an array such as
`"${myarray[*]}"`)

With quotes, splat expands to each argument, concatenated into a single
string by using the first character of the *IFS* variable to join the
terms.

For example, if the positional arguments are *one*, *two* and *three*,
then `"$*"` expands to "one two three" if *IFS* is the default value.

When set to empty, however, the above parameters would expand to
"onetwothree", which is typically not useful.  This pretty much makes
the splat expansion useless (we'll revisit this later, however).

Instead you can use the `$@` expansion.  When *IFS* is empty, it expands
to the positional parameters.  It doesn't generally need to be quoted,
but quoting won't hurt it either.

Also, while unquoted `$@` works to generate the separate positional
arguments, special expansions of `$@`, such as `${@#--}` which removes
leading double-dashes from each argument, require double-quotes to work:
`"${@#--}"`.

Another Exception
-----------------

If you haven't been quoting variable expansion up until now, you'll
probably run into this one eventually.  It's less of an issue with an
unset IFS, but it still happens.

Normally, when a variable contains a blank value, bash will strip that
value away whenever it is expanded without quotes.  A blank value is
either an empty string or one which consists solely of whitespace.  The
whitespace characters must be in *IFS*, however.

Here's an example on the command line (default *IFS*):

{% highlight bash %}
> numargs () { echo "Number of arguments is: $#" ;}
> myvar=' '
> numargs "$myvar"
Number of arguments is: 1
> numargs $myvar
Number of arguments is: 0
{% endhighlight %}

The *myvar* expansion without quotes was simply swept away and not fed
to *numargs*.

This can especially be an issue if the expansion is part of a larger set
of arguments to a function call:

{% highlight bash %}
myfunc $one $two $three
{% endhighlight %}

If *two* expands to whitespace or an empty string, it will disappear,
and the value of *three* will be the second argument to *myfunc* rather
than the third.  That's not what you want.

When *IFS* is unset, bash will only strip empty expansions, not
whitespace ones, so a variable which has at least one character in it
won't be stripped.  An empty value being stripped can still cause the
problems I just described.

There are two ways to deal with this.  The first is to simply quote all
expansions, which gets us back to square one.  Oh well, but it's
reasonable.

The second is to simply bear in mind the occasions where a variable may
legitimately expand to an empty string, and to quote those occasions
only.

That gives much better looking code, but it requires more mindfulness.
If you're writing a function which accepts empty arguments, be sure
write tests which use empty arguments.  You'll need to quote those
arguments within your function.

It's up to you how you want to approach it.  Personally I think it's
worth the extra mindfulness on occasion in order to avoid having to
quote everything all the time.

Aside from empty argument removal, there's one more issue which can
affect unquoted expansions, which we'll discuss next.

Continue with [part 19.5] - disabling path expansion

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-31-approach-bash-like-a-developer-part-18-word-splitting            %}
  [Internal Field Separator]: http://mywiki.wooledge.org/IFS
  [here]:         https://www.gnu.org/software/bash/manual/bashref.html#Word-Splitting
  [splat]:        https://ss64.com/bash/syntax-pronounce.html#10
  [part 19.5]:      {% post_url 2018-09-09-approach-bash-like-a-developer-part-19.5-disabling-path-expansion %}
