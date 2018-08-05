---
layout: post
title:  "Approach Bash Like a Developer - Part 9 - Another Test"
date:   2018-08-05 00:00:00 +0000
categories: bash
---

This is part nine of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we factored our support function into a library and sourced
it. We forgot something, however...there's no test for the *sourced*
function!  Let's fix that now.

*shpec/support_shpec.bash:*

{% highlight bash %}
support_lib=$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")/../lib/support.bash

describe sourced
  it "returns true when in a file being sourced"
    dir=$(mktemp --quiet --directory)
    echo "source '$support_lib'; sourced" >"$dir"/example
    (source "$dir"/example)
    assert equal 0 $?
    rm --recursive --force "$dir"
  end

  it "returns false when that file is run"
    dir=$(mktemp --quiet --directory)
    echo "source '$support_lib'; sourced" >"$dir"/example
    chmod 775 "$dir"/example
    "$dir"/example
    assert unequal 0 $?
    rm --recursive --force "$dir"
  end
end
{% endhighlight %}

Shpec output:

{% highlight bash %}
> shpec shpec/support_shpec.bash
sourced
  returns true when in a file being sourced
  returns false when that file is run
2 examples, 0 failures
0m0.000s 0m0.000s
0m0.000s 0m0.000s
{% endhighlight %}

This one is quite a bit trickier than our earlier tests. The function we
want to test, *sourced*, has to be in another file, not this test file.

Since we'll be creating a file, we'll take advantage of unix's *mktemp*
command, which will create a directory in a temporary location.  When
we're done with it, we'll use *rm* to remove the directory.

One bit of preparation at the top of the file is to pin down the
location of the `support.bash` file explicitly, since the temporary file
won't have the benefit of a fixed location relative to it.

Let's look at the first test, piece by piece:

{% highlight bash %}
dir=$(mktemp --quiet --directory)
{% endhighlight %}

Here we make the test directory.

{% highlight bash %}
echo "source '$support_lib'; sourced" >"$dir"/example
{% endhighlight %}

This line creates the example file which will be sourced, importing and
calling the *sourced* function. The semicolon separates the two
statements so there only needs to be one *echo* statement.

{% highlight bash %}
(source "$dir"/example)
{% endhighlight %}

Here we source the file.  On principle, we're using a subshell which are
the surrounding parentheses.  The subshell creates a new context, kind
of like a sandbox.

Anything that would normally come into this shell's namespace from
sourcing a file will now go into the subshell's.  When the subshell
ends, those changes will go away and not pollute the current shell's
namespace.

The return code from the *source* will be the return code of the
subshell, so the following line will still test the correct value:

{% highlight bash %}
assert equal 0 $?
{% endhighlight %}

Since all the file does is return the value returned by *sourced*, it
should be 0, which is bash's *ok* return value.  `$?` refers to the
return value of the last command.

{% highlight bash %}
rm --recursive --force "$dir"
{% endhighlight %}

Now we clean up the file and directory.

The second test works the same as the first, but sets the file
executable and runs it instead.  This time we expect *false* from
*sourced*, which is why the *assert* tests for `$?` to be unequal to
zero.

Also, since running a file automatically creates its own shell instance,
we don't need to manually create a subshell context for it.

One last thing that I'll note about the *sourced* function is that it
can only be called in the main body of a script, not from inside a
function.  If it appears inside a function, that function will be the
name it tests against "source", and it will return the wrong result.

Continue with [part 10]

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro            %}
  [Last time]:  {% post_url 2018-08-04-approach-bash-like-a-developer-part-8-support-library  %}