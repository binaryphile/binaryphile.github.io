---
layout: post
title:  "Determining the Location of Your Script in Bash"
date:   2020-01-12 05:00:00 +0000
categories: bash
---

Hey there!  Long time no blog.  It's been about a year and a half since
I concluded the series on [approaching bash like a developer].  It's
good to be back!  I've learned a lot since then and a number of my
practices have evolved, a subject which I hope to get into with perhaps
a summary of my current best practices.

But that's not the subject of today's post.  This one is to blow out the
rust and get familiar with the github pages blogging system again.  So
here we go.

One of the first things I end up doing in almost all of my bash scripts
is to figure out where the heck it is.  This is important so you can
modularize your script into a few files if it gets unwieldy and source
them from your main file.  Pretty soon you may even have a few must-have
functions for all of your scripts that you include as a library, in
which case you'll need to load them without the trouble of sticking them
on the **PATH** (the source builtin searches PATH, you knew that
right?).

TL;DR
-----

Here's the general solution, details further down:

``` bash
HERE=$({ cd "$(dirname "$BASH_SOURCE")"; cd -P "$(dirname "$(readlink "$BASH_SOURCE" || echo "$BASH_SOURCE")")"; } >/dev/null; pwd)
```

For a simpler version which gives an absolute path but doesn't allow you
to symlink to the script itself, here's the less-recommended version:

``` bash
HERE=$(cd -P "$(dirname "$BASH_SOURCE")" >/dev/null; pwd)
```

If you don't care about absolute pathnames and just want something you
can remember, again no symlinking:

``` bash
HERE=$(dirname "$BASH_SOURCE")
```

That last one is for when you won't be changing working directory before
using the value and you don't care how it looks when printed.

The Long Way Round
------------------

Most languages are "package-oriented", which means they can find other
source files which are located in a path relative to the current source
file without too much trouble.  While bash does know the current
location of the file in some sense, it doesn't do anything to make it
easy on you.

For example, you could use the special parameter **$0**.  It expands to
the name of the script file as invoked on the command line.  If the
script was executed by invoking its full path, such as
**/home/ted/scripts/myscript**, this would be mostly what you need but
that's not how a script is usually invoked.  More often it's called
simply the name of the script, perhaps prepended with the current
directory if the script isn't on the PATH, a la **./myscript**.  This
doesn't really get us where we need to be.

Not only that, $0 suffers from another issue.  If the script we're
writing is a command, it can be fine.  However, if we're writing a
library which is for use by other scripts, $0 will give us the name of
the script which called the library, not that of the library file
itself.  If the goal is to figure out where the library file is so it
can find other libraries relative to itself, this won't work.

Fortunately bash provides a special variable, **BASH_SOURCE**, which
always tells the name of the file in which it appears, whether or not
that file was executed as a command or sourced by another script.  So
BASH_SOURCE is more generally useful than $0 for our purposes. (although
if you're looking for the command name as invoked by the user, $0 is
still your buddy)

The Gang's All HERE
-------------------

Let's say we want to store the script location in the variable
**HERE**.  Look at the following:

``` bash
# This is simple and works in many cases but isn't completely general
HERE=$(dirname "$BASH_SOURCE")
```

The quotes may be necessary and are good practice if you haven't changed
**IFS**, since they protect against spaces in path names.  In the rest
of my examples I won't worry about correct quotation since I usually set
IFS to newline.

`dirname $BASH_SOURCE` gives us a few possible results based on how the
script was found:

-   **`source ./myscript`** - dirname will explicitly trim the basename
    off the given path, returning "."

-   **`source scripts/myscript`** - this time we'll get the relative
    path "scripts".  This is really the same as the above in mechanics,
    I just wanted to explicitly call out "./" as a valid way to provide
    a relative path since it's pretty common in practice

-   **`source /home/ted/scripts/myscript`** - a full path this time

-   **`source myscript`** - if no path was given with the script name,
    there are two possibilities: the file is on the PATH, in which case
    we'll get the fully-qualified PATH directory in which it was found.
    Or the file wasn't on the PATH but is in the current directory, in
    which case dirname will only see the bare filename and will return
    ".".  The PATH search comes first, so if both are true, PATH wins.

-   **`myscript`** - if we are executing the file rather than sourcing
    it there's a slight difference.  While source will find a file which
    isn't on the PATH but *is* in the current directory, running the
    file as an executable *will not* find a file in the current
    directory.  You have to qualify it with a directory reference, e.g.
    **`./myscript`** (in which case we've covered this in the first
    option above), so **`myscript`** by itself won't even run without
    being on the PATH.

The first two options return relative paths, as does the case where the
file isn't on the PATH in the second-to-last option.  Even a "." is considered a
correct, if superfluous, relative path.

We can ignore the full path scenario since that will always work
correctly, so long as we don't munge it when it is given.

So coming back to the relative paths, they actually don't inherently
present a problem if we can rely on two other factors:

-   the current working directory never changes before we want to use
    the location, in which case a relative reference works fine because
    it gets tacked onto the current working directory to generate a full
    path

-   there are no symlinks involved.  If the path to a script includes
    symlinks, then the relative files we're trying to locate from it may
    not have similar symlinks and so appear to be missing based on the
    user's invocation via the symlinked location. (remember that we're
    using BASH_SOURCE, and it can only give us the symlink location)

Let's tackle the issue of a symlink next.  Consider the following
filesystem layout:

```
/home/ted
├── bin
│   └── myscript -> /home/ted/scripts/myscript
└── scripts
    ├── lib.bash
    └── myscript
```

myscript really lives in **/home/ted/scripts**, but I've linked it into
my **bin** directory.  **/home/ted/bin** is on my PATH, so I can run myscript from anywhere just by executing
**`myscript`**.

In addition, myscript contains the following lines:

``` bash
HERE=$(dirname $BASH_SOURCE)
source $HERE/lib.bash
```

Unfortunately, this will not find **lib.bash** and will fail.  The
reason why is that HERE will be set to **/home/ted/bin** because that is
where it was found on the PATH when I ran it.  (it would be similar if I
were sourcing it)

There are many commands to resolve symlinks but they vary on different
Unix distros.  **readlink** is the most common, but it varies in its
capabilities from BSD (i.e. Mac) to GNU.  In a perfect world, we could
use GNU's **readlink -f** and be done with it, but Mac's readlink
doesn't support the -f option, and installing the GNU version gives the
**greadlink** command so as not to break the Mac's native one.  Figuring
this out in a one-liner (and requiring GNU readlink's installation) is
more effort than it's worth.

Instead, you can use the bare readlink command.  When readlink is run on
a symlink, it returns the contents of the symlink (a path reference).
That's it.  If the file isn't a symlink, readlink returns nothing but an
error.  This is consistent across Mac and GNU.  We can use it this way:

``` bash
HERE=$(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE))
```

If BASH_SOURCE is a symlink, readlink feeds it's contents (the real
path) to dirname.  Otherwise readlink errors and the second part of the
expression executes, which simply echos to dirname the original
BASH_SOURCE.

So long as the symlink contains a full path to the script and that path
doesn't itself point to another symlink, HERE will get the correct
original directory of the script.  **readlink -f** would resolve any
number of chained symlinks, but I'm not going to be able to do the same
with a one-liner and I've decided to be happy categorizing chained
symlinks as being outside the scope of my use case.

Resolving to an Absolute Directory Name
---------------------------------------

I mentioned that relative pathnames work in most cases, but let's say
that they're icky.  We're still getting relative pathnames in a number
of cases as outlined earlier.  And they really are icky since they won't
work if our script changes working directory before using HERE.

Here's how to get the full pathname.  As an added bonus, it finds the
true path of any symlinks in the directory part of the path (as opposed
to the file itself being a symlink).

While symlinks in the path usually aren't harmful since they don't tend
to invalidate the relative location of sibling files, having the actual
path can't hurt and is arguably good if you're a purist:

``` bash
HERE=$(cd -P $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)) >/dev/null; pwd)
```

This changes to the script's directory and prints the working path
(**pwd**), but doesn't affect the state of our script since it's being
done in a subshell (the **$()** expansion).

If we didn't care about the true path, we could drop the **-P** option
to cd since that resolves symlinks on the path, but as I said, it can't
hurt.  When you run the bash builtin pwd, it outputs the full path of
the current directory, which is what we're looking for.

I'm also binning cd's output to **/dev/null** since setting **CDPATH**
can make it generate output to stdout which we don't want.  Normally
that's not an issue but I've seen it happen.  Can't be too safe here.

Note that for **pwd**, we could also have echoed the special **PWD**
variable.  It doesn't matter, pwd is just shorter to write.

The Last Bit, Relative Symlinks
-------------------------------

So the last thing we have to deal with is when we symlink to the
executable with a relative symlink, as in the following:

```
/home/ted
├── bin
│   └── myscript -> ../scripts/myscript
└── scripts
    ├── lib.bash
    └── myscript
```

The problem here is that our dirname/readlink will return
**../scripts**, but we won't be in the correct working directory when we
try to cd to it.

The answer is just to cd to that directory first.  Since we're sending
cd's output to **/dev/null**, we can group to the two cd commands
together with braces and bin their collective output:

``` bash
HERE=$({ cd $(dirname $BASH_SOURCE); cd -P $(dirname $(readlink $BASH_SOURCE || echo $BASH_SOURCE)); } >/dev/null; pwd)
```

The second cd does require a semicolon before closing the braces.

There you go, a battle-hardened, fully normalized directory spec which
handles relative symlinks on both Mac and Linux.  Whew!

  [approaching bash like a developer]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
