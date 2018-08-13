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
`set -o`.  In order to unset any of them, you use `set +o` instead.

Test Drive
----------

This time, let's start with the tests.  We'll implement our
*strict_mode* function in *lib/support.bash*.

*shpec/support_shpec.bash:*

{% highlight bash %}
set -o nounset

support_lib=$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")/../lib/support.bash
source "$support_lib"

[...]

describe strict_mode
  it "sets errexit"; (_shpec_failures=0
    strict_mode on
    [[ $- == *e* ]]       # errexit shows up as "e" in $-
    assert equal 0 $?     # result code 0 means true
    return "$_shpec_failures"); (( _shpec_failures += $? ))
  end
end
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
it "unsets errexit"; (_shpec_failures=0
  set -o errexit    # set it so we really test turning it off
  strict_mode off
  [[ $- == *e* ]]
  assert unequal 0 $?
  return "$_shpec_failures"); (( _shpec_failures += $? ))
end
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
  it "sets errexit"; (_shpec_failures=0
    strict_mode on
    [[ $- == *e* ]]
    assert equal 0 $?
    return "$_shpec_failures"); (( _shpec_failures += $? ))
  end

  it "unsets errexit"; (_shpec_failures=0
    set -o errexit
    strict_mode off
    [[ $- == *e* ]]
    assert unequal 0 $?
    return "$_shpec_failures"); (( _shpec_failures += $? ))
  end

  it "sets nounset"; (_shpec_failures=0
    set +o nounset    # unset it first because set at top of file
    strict_mode on
    set +o errexit    # so test won't exit if it fails
    [[ $- == *u* ]]
    assert equal 0 $?
    return "$_shpec_failures"); (( _shpec_failures += $? ))
  end

  it "sets pipefail"; (_shpec_failures=0
    strict_mode on
    set +o errexit
    # following looks at result of "set -o" with a regexp
    [[ $(set -o) =~ pipefail[[:space:]]+on ]]
    assert equal 0 $?
    return "$_shpec_failures"); (( _shpec_failures += $? ))
  end
end
{% endhighlight %}

The test for *pipefail* has to list the full set of settings with `set
-o`.  The status of pipefail is listed as "off" or "on".  The test looks
for that result by using the whitespace matcher "[[:space:]]+" between
the words "pipefail" and "on".

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

Continue with [part 14]

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                    %}
  [Last time]:  {% post_url 2018-08-09-approach-bash-like-a-developer-part-12-working-in-strict-mode  %}
