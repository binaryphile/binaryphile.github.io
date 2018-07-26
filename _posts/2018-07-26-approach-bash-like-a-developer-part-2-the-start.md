---
layout: post
title:  "Approach Bash Like a Developer - Part 2 - The Start"
date:   2018-07-26 00:00:00 +0000
categories: bash
---

This is part one of a series on how to approach bash programming in a
way that's safer and more structured than your basic script, as taught
by most tutorials.

Getting Started with Bash
-------------------------

I'm going to assume at least a passing familiarity with bash
programming, while still covering the facets of the basics on which this
series will rely.

If you don't have a familiarity with bash, you'll be better served by
starting somewhere like the following and coming back to this series
once you've gotten your feet wet:

-   [Bash Shell Scripting]

If you're on Linux, you should only need to open a terminal session to
start a bash prompt.

On MacOS, you should have bash on your terminal command-line as well,
however, it will be a very old version of bash.  God knows why Apple
can't seem to fix this.

Fortunately, there is the necessary crutch of [homebrew] which exists to
make the Mac command-line useful.  You should definitely use it to
install bash, which will then be a reasonable version.

Shebang, Shebang
----------------

The first evergreen question of bash scripting: how to start my script?

Old as the classic spaces-vs-tabs debate, venerable as vi-vs-emacs, the
two contenders are:

{% highlight bash %}
    #!/bin/bash
{% endhighlight %}

and

{% highlight bash %}
    #!/usr/bin/env bash
{% endhighlight %}

Which to use?

Well, it doesn't really matter for the most part, unless you're on a Mac
and using homebrew (always a catch, right?).

That is to say, if your bash is not installed as `/bin/bash`, then
naturally you'll want to use the `#!/usr/bin/env bash` iteration of the
[shebang].  That's because `/usr/bin/env` will force the system to
search the path for `bash`, which will end up being whatever bash is
preferred in your path.  Usually this is the right choice.  It has the
benefit of making your script compatible with environments which *don't*
have `/bin/bash`, such as when you want to be executable on a Mac with a
recent bash.

However, if you don't want run-time determination of which bash will be
used to invoke your script, you may prefer the shebang to be hardwired
to `/bin/bash` (or other).  That's fine as well, as long as you know
what you're getting.  You may need to code to a particular version of
bash then (yes, the bash language occasionally does change
version-to-version).  This may be worth it, for example, in order to
lock a known bash for, say, an init script which will be run as root.

It's up to you.  I usually prefer to trust the user's path and use
`#!/usr/bin/env bash` for portability, except in the case of init
scripts or other situations where hardwired dependencies are at a
premium.

Extension a File with the IRS
-----------------------------

So, then, what to name the file?  Well, that's really up to you as well.

However, there is the question of the file extension, a topic almost as
weathered as our last question.

I pretty much agree with the [google guidelines], with one exception:

-   Executable scripts get no extension

-   Bourne-shell compatible scripts get the `.sh` extension

-   Any file which uses bash-specific syntax gets the `.bash` extension

Executable files in any non-scripting language don't care to specify
their source langage as a file extension.  There's no reason bash
scripts need to either.  Despite the fact that many developers include
the `.sh` extension on any shell file, I don't see a need for it.  It's
simply extraneous information.

To be fair, one possibly valid reason is that you use a
syntax-highlighting editor which doesn't detect the filetype correctly
unless the file has the `.sh` extension.  Consider getting a new editor.

Any executable bash script will have the shebang as the first line.  Any
editor worth its salt should detect such and offer the correct
highlighting automatically.  The file shouldn't need an extension to
detect the filetype.

I agree with the google guidelines that libraries (files only containing
code for other programs) should have a file extension.  This is
especially true since libraries typically will not have a shebang and
therefore won't have their syntax auto-detected without an extension.

However, I part ways at using the `.sh` extension exclusively.  Any file
with the `.sh` extension should be Bourne shell-compatible.  If you are
using bash, you should take advantage of its numerous improvements over
the Bourne shell (otherwise, stop reading this series right here).  If
you do so, you therefore shouldn't use the `.sh` extension since your
script won't be `.sh`-compatible.  To be clear and proper, use `.bash`
instead.

Continue with [part 3].

  [Bash Shell Scripting]: https://en.wikibooks.org/wiki/Bash_Shell_Scripting
  [homebrew]: https://brew.sh
  [shebang]: https://en.wikipedia.org/wiki/Shebang_(Unix)
  [google guidelines]: https://google.github.io/styleguide/shell.xml#File_Extensions
  [part 3]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-3-the-test %}
