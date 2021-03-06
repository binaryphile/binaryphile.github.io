---
layout: post
title:  "Approach Bash Like a Developer - Part 13 - Implementing Strict Mode"
date:   2018-08-12 00:00:00 +0000
categories: bash
---

This is part thirteen of a series on how to approach bash programming in
a way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed techniques for working in strict mode.  This
time, let's TDD a function to implement strict mode.

As a reminder, setting any of the strict mode settings involves calling
*set -o*.  In order to unset any of them, you use *set +o* instead.

Test Drive
----------

This time, let's start with the tests.  We'll implement our
*strict_mode* function in *lib/support.bash*.

Before we start with the code, let me tell you how I work iteratively
with shpec.

The easiest way to run tests is to have them automatically run when your
work is saved.  This way you can write the test, see it fail and then
see it pass (or fail) as soon as you've written your script to disk.

I use a combination of the linux *find* command along with the *[entr]*
tool to do so:

{% highlight bash %}
alias tdd='find . -path ./.git -prune -o -type f -print | entr bash -c "shpec $1"'
{% endhighlight %}

*entr* can be installed on ubuntu with the command *sudo apt-get install
-y entr*.

I run this command in the directory above my *lib* and *shpec*
directories like so:

{% highlight bash %}
tdd shpec/testfile_shpec.bash
{% endhighlight %}

*entr* monitors the files given by *find* for changes on disk, then runs
the *shpec* command.  Because it's run from the directory above, it sees
changes in both the shpec file as well as the script file.

Keeping this in one window while I work in the editor in another lets me
see results instantly.

Now the test.

*shpec/support_shpec.bash:*

{% highlight bash %}
set -o nounset
shopt -s expand_aliases
alias it='(_shpec_failures=0; alias setup &>/dev/null && { setup; unalias setup; alias teardown &>/dev/null && trap teardown EXIT ;}; it'
alias ti='return "$_shpec_failures"); (( _shpec_failures += $?, _shpec_examples++ ))'
alias end_describe='end; unalias setup teardown 2>/dev/null'

support_lib=$(dirname "$(readlink -f "$BASH_SOURCE")")/../lib/support.bash

[...]

source "$support_lib"

describe strict_mode
  it "sets errexit"
    strict_mode on
    [[ $- == *e* ]]       # errexit shows up as "e" in $-
    assert equal 0 $?     # result code 0 means true
  ti
end_describe
{% endhighlight %}

This fails since we don't yet have *strict_mode*.  Let's remedy that.

*lib/support.bash:*

{% highlight bash %}
[...]

strict_mode () {
  set -o errexit
}
{% endhighlight %}

This passes, so on to the next test:

{% highlight bash %}
it "unsets errexit"
  set -o errexit    # set it so we really test turning it off
  strict_mode off
  [[ $- == *e* ]]
  assert unequal 0 $?
ti
{% endhighlight %}

Run shpec and failure again.  Good.

*support.bash* again:

{% highlight bash %}
strict_mode () {
  case $1 in
    on  ) set -o errexit;;
    off ) set +o errexit;;
  esac
}
{% endhighlight %}

Pass.  The tests for *pipefail* and *nounset* are similar.  I don't
bother testing the off setting for the other two.

Here's the entirety of *strict_mode* testing in
*shpec/support_shpec.bash:*

{% highlight bash %}
describe strict_mode
  it "sets errexit"
    strict_mode on
    [[ $- == *e* ]]
    assert equal 0 $?
  ti

  it "unsets errexit"
    set -o errexit
    strict_mode off
    [[ $- == *e* ]]
    assert unequal 0 $?
  ti

  it "sets nounset"
    set +o nounset    # unset it first because set at top of file
    strict_mode on
    set +o errexit    # so test won't exit if it fails
    [[ $- == *u* ]]
    assert equal 0 $?
  ti

  it "sets pipefail"
    strict_mode on
    set +o errexit
    [[ :$SHELLOPTS: == *:pipefail:* ]]
    assert equal 0 $?
  ti
end_describe
{% endhighlight %}

And finally, *lib/support.bash:*

{% highlight bash %}
strict_mode () {
  case $1 in
    on )
      set -o errexit
      set -o nounset
      set -o pipefail
      ;;
    off )
      set +o errexit
      set +o nounset
      set +o pipefail
      ;;
  esac
}
{% endhighlight %}

Continue with [part 14] - updated outline

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                    %}
  [Last time]:  {% post_url 2018-08-09-approach-bash-like-a-developer-part-12-working-in-strict-mode  %}
  [entr]:       http://www.entrproject.org/
  [part 14]:    {% post_url 2018-08-13-approach-bash-like-a-developer-part-14-updated-outline         %}
