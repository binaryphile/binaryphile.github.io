---
layout: post
title:  "Approach Bash Like a Developer - Part 21 - Environment Variables"
date:   2018-09-02 00:00:00 +0000
categories: bash
---

This is part 21 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed variable scoping and how to protect variables
from out-of-scope modification.  This time, let's discuss environment
variables.

Variables in bash exist only within the current shell context and within
what bash terms [subshells].  Subshells are sets of commands grouped
with parentheses, which run a copy of the parent shell as a subprocess.

A subshell creates a separate process with an exact copy of the parent
shell, including all of its variables.  When it ends, however, any
changes to variables are also gone and the parent shell is (still) in
the same state as it was prior to the subshell.

Aside from subshells, however, regular shell variables are not inherited
by processes run from the shell.  For example, running a program from
the command line (even another copy of bash itself) doesn't allow the
child process to receive the regular bash variables defined in the
parent shell.

Environmentalism
----------------

Environment variables are a special kind of shell variable.  Unlike
regular variables, environment variables are propagated to processes run
from the shell.  They are, of course, also available to subshells as
well.

By convention, environment variables are typically named in all caps,
such as *PATH*, although this is not a requirement.  The shell
automatically creates a number of environment variables (all with
all-caps names), but anyone can create them via *export* statements,
such as in a *.bash_profile* file:

{% highlight bash %}
export MYVAR=myvalue
{% endhighlight %}

Environment variables can also be created by prefixing a command with an
assignment to a variable name:

{% highlight bash %}
> MYVAR=myvalue bash -c 'declare -p MYVAR'
# -x means exported, a.k.a. an environment variable
declare -x MYVAR=myvalue
{% endhighlight %}

Such a declaration creates the environment variable for the subprocess
but does not create it in the current shell.

Just because a variable is all caps doesn't make it an environment
variable, however.  While that is the convention, bash itself makes
several special variables available in all caps which are simply shell
variables, not environment variables.  When in doubt, check to see
whether a variable is in the environment or not with either *declare -p*
or *printenv*.

{% highlight bash %}
> printenv CDPATH
# no output because CDPATH is not an environment variable
{% endhighlight %}

Here is a list of [special shell variables] in bash.

Continue with [part 22] - data types

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-01-approach-bash-like-a-developer-part-20-scoping                   %}
  [subshells]:    http://wiki.bash-hackers.org/syntax/ccmd/grouping_subshell
  [special shell variables]: http://wiki.bash-hackers.org/syntax/shellvars
  [part 22]:      {% post_url 2018-09-02-approach-bash-like-a-developer-part-22-data-types                %}
