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
source "$(dirname "$(readlink -f "$BASH_SOURCE")")"/../lib/support.bash
{% endhighlight %}

After:

{% highlight bash %}
IFS=''
source $(dirname $(readlink -f $BASH_SOURCE))/../lib/support.bash
{% endhighlight %}

Still pretty thorny, but that just means every bit of noise we can
squeeze out counts all the more.

Additionally, now you don't have to think about how quotations nest
inside command substitutions, which can be non-intuitive even (or
especially) to programmers of other languages.

An Exception
------------

There are two special parameter expansions which are affected by the
disabling of word splitting.

The first is the `$*` expansion, which I'll call the [splat] expansion.

The splat expansion is the means by which you can concatenate all of the
current positional arguments into a whitespace-delimited string.

Without quotes, splat expands to each argument individually.

With quotes, splat expands to each argument, concatenated into a single
string by using the first character of the *IFS* variable to join the
terms.

For example, if the positional arguments are *one*, *two* and *three*,
then `"$*"` expands to "one two three" if *IFS* is the default value.

When set to empty, however, the above parameters would expand to
"onetwothree", which is typically not useful.

If you don't need a single string, then you can use the bare splat
expansion to reference all positional variables.

When *IFS* is empty, however, the unquoted at expansion `$@` expands to
the separate positional parameters, so it's the same as `$*`.  Quoted,
it expands to "one two three" with spaces, so it's generally more useful
than splat.

For example, to generate the string "Arguments are one two three" when
IFS is empty, the expansion "Arguments are $@" would work while
"Arguments are $*" would not.

Also, while unquoted `$@` works to generate the separate positional
arguments, special expansions of `$@`, such as `${@#--}` to remove
leading double-dashes, don't work without double quotes: `"${@#--}"`.

Another Exception
-----------------

If you haven't been quoting variable expansion up until now, you'll
probably run into this one eventually.  It unfortunately is still an
issue when you turn off word splitting.

When a variable contains a blank value, bash will strip that value away
whenever it is expanded without quotation marks.  A blank value is
either an empty string or one which consists solely of whitespace.

Here's an example on the command line:

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
than the third.  That's certainly not the desired behavior.

There are two ways to deal with this.  The first is to simply quote all
expansions, which gets us back to square one.  Oh well, but it's
reasonable.

The second is to simply bear in mind the occasions where a variable may
legitimately expand to whitespace or an empty string, and to quote those
occasions only.

That gives much better looking code in most cases, but it requires more
mindfulness.  If you're writing a function which accepts blank
arguments, be sure write tests which use blank arguments to ensure that
your results come out correctly as well.  That means you will need to
employ quoting everywhere that argument is used within your function.

This is by far the biggest drawback of trying not to use double-quotes
everywhere.  It's up to you how you want to approach it.  Personally I
think it's worth the extra mindfulness on occasion in order to avoid
having to quote everything all the time.

Aside from blank argument removal, there's one more issue which can
affect unquoted expansions, which we'll discuss next.

Continue with [part 19.5] - disabling path expansion

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-31-approach-bash-like-a-developer-part-18-word-splitting            %}
  [Internal Field Separator]: http://mywiki.wooledge.org/IFS
  [here]:         https://www.gnu.org/software/bash/manual/bashref.html#Word-Splitting
  [splat]:        https://ss64.com/bash/syntax-pronounce.html#10
  [part 19.5]:      {% post_url 2018-09-09-approach-bash-like-a-developer-part-19.5-disabling-path-expansion %}
