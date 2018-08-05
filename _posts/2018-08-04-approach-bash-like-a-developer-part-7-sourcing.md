---
layout: post
title:  "Approach Bash Like a Developer - Part 7 - Sourcing"
date:   2018-08-04 00:00:00 +0000
categories: bash
---

This is part seven of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we outlined a template script compatible with testing. This
time we'll look at how to source a file.

Use the Source
--------------

The primary issue with sourcing files in bash is that any relative
reference to a file is dependent on the current working directory when
the file is executed.  It's not based on where the script file is
located.

Thus if you know the absolute pathname of the file you want sourced, you
can use that reliably.  However you can't rely on a relative pathname
such as `./mylibrary.bash`, even if it's in the same directory as the
script containing the directive.

There are normally two options. The first is that you don't specify a
pathname other than the filename itself, neither relative nor absolute.
Instead, you put the library somewhere on your PATH, which is searched
automatically by the *source*, or `.`, command. This means that not only
does the user have to do an installation step for the script to work
(modify PATH), but also that finding the file correctly depends on not
having another file of the same name earlier in the PATH.

The second option is discover the path of the current file and source
the target file relative to that path. Here's what that looks like:

    source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/path/to/file

Breaking it down, first there is `$BASH_SOURCE`.  This is a reference to
the first element of the *[BASH_SOURCE]* array, which is the current file,
relative to where it was called from.  For example, if the file were
executed from its own directory, it might simply contain the filename
nad nothing more.

Because we need the pathname to the current file, we use `readlink
--canonicalize`.  This is a feature of GNU readlink which returns the
precise path, including filename, of the argument. It even resolves
symlinks to the true path of the file.  There is an alternative called
`realpath` which does the same thing, but is not as available on the
platforms on which I work.

While that returns the filename included with the path, we only want the
directory name, so *dirname* finishes the job. After that we simply
append the relative path to the file we wish to source.

Note that the quotation marks are important, but we'll get into those in
a later post.

Also note that the double-dashes are slightly less important, but good
practice for safe bash programming.

Continue with [part 8] - utility library

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro            %}
  [Last time]:    {% post_url 2018-07-30-approach-bash-like-a-developer-part-6-outline-script   %}
  [BASH_SOURCE]:  http://wiki.bash-hackers.org/syntax/shellvars#bash_source
  [part 8]:       {% post_url 2018-08-04-approach-bash-like-a-developer-part-8-utility-library  %}
