---
layout: post
title:  "Approach Bash Like a Developer - Part 11 - Strict Mode"
date:   2018-08-09 00:00:00 +0000
categories: bash
---

This is part eleven of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed the uses of aliases in scripting.  This time,
let's add a so-called "strict mode" so scripts tend to catch errors and
stop rather than let them go by.

Normally, bash is pretty forgiving about errors.  If a script runs a
command which returns an error, bash generally ignores the error and
keeps going.

This can be a problem, since further commands may have relied on the
erroring command to have completed successfully.  While usually that
just means that the further commands will also fail, sometimes their
failure mode may have negative consequences.  Also, further commands may
waste significant amounts of time and/or resources on a task which is
now doomed to fail because of the earlier failure.

Some languages, much like bash, require you to check the result code
from a function or command to detect an error and require you to
explicitly stop execution at such a point, for example by calling
*return* or *exit*.

While this has some history as a practice, it is also extremely verbose
and error-prone. You end up coding for every possible error case, which
obscures the intent of your code. Or you miss the error cases and the
program continues, resulting in the issues discussed earlier. This
approach requires programmer perfection in order to work correctly.

Most modern programming languages handle these issues with an
[*exception*]-based error system. Bash doesn't have such a method, but
you can at least tell it to stop on errors rather than continue blindly.

While a developer mindset favors strictness, this approach in bash
requires some understanding and practices to mitigate its downsides.
This and the following posts will outline the details.

Before I start, however, a tip of the hat is due to Aaron Maxwell's
[excellent article] on strict mode, which is what inspired me and I'm
sure many others to explore using it.  His article and ideas fully cover
everything I'm about to discuss in this part of the series.  I've got a
slightly different perspective and wording, perhaps, but you can
fundamentally get everything from his material.

Strict Mode Settings
--------------------

To get started, let's talk about the three settings which constitute a
strict mode for bash:

-   *nounset* - exit when a variable is referenced but not set

-   *pipefail* - make the final return code of a set of piped commands
    be failure if any command in the pipeline failed

-   *errexit* - exit when a command returns an error code

### Nounset

Any variable you reference for its value should both exist as well as
have had a value set for it.

Normally bash will simply return an empty string if either of these
things isn't true.  This isn't good enough for strict mode, since it
allows the script to continue when the programmer may have made a typo
with the variable name, or some other mistake.

Make bash exit with an error message if an undefined variable is
referenced:

    set -o nounset

This is also sometimes accomplished with the following, but I prefer the
more explicit version above:

    set -u

### Pipefail

Piping is a common idiom in bash, where one command's output is fed to
another's input by the *|* character.

The pipe generally returns the code of the last command in the pipe.
This can mask a failure of a command earlier in the pipeline.  In strict
mode, we want to see such failures so they can trigger the next setting,
*errexit*.

Make a pipeline return the failure of any command in it:

    set -o pipefail

There is no short version of this setting.

### Errexit

Finally, there's *errexit*. *Errexit* tells bash to exit the script with
a message whenever a command returns an error code.  This is the bulk of
strict mode:

    set -o errexit

Short version:

    set -e

Continue with [part 12] - working in strict mode

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                    %}
  [Last time]:  {% post_url 2018-08-23-approach-bash-like-a-developer-part-10.5-aside-on-aliases      %}
  [excellent article]: http://redsymbol.net/articles/unofficial-bash-strict-mode/
  [part 12]:    {% post_url 2018-08-09-approach-bash-like-a-developer-part-12-working-in-strict-mode  %}
