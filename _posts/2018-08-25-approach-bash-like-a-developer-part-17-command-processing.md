---
layout: post
title:  "Approach Bash Like a Developer - Part 17 - Command Processing"
date:   2018-08-25 00:00:00 +0000
categories: bash
---

This is part seventeen of a series on how to approach bash programming
in a way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we recapped what has been discussed and what's next.  This
time, let's go over bash command processing.

First Things First
------------------

So, after typing a command and hitting enter, what's the first thing
that happens?

The most thorough explanation I've found is from the [Practical Guide to
UNIX for MacOS X Users], but I'll also link to the bash hacker's wiki.
Here's what happens:

-   history expansion - substitute a reference to an older command -
    e.g. repeating the last command:

        !!

-   alias substitution - substitute a string in for the first word of a
    simple command, perhaps recursively if an alias expands to another
    alias - e.g. for the alias `alias ls='ls -l'`, expand `ls` to:

        ls -l

    Aliases can resolve into other aliases, but evaluation stops if it
    resolves into itself, hence no recursion for the alias given here.

-   parsing - identify important syntactical tokens such as semicolons,
    parentheses, braces, pipe and redirection characters and determine
    the grammatical structure of the resulting statement

-   brace expansion - substitute a brace expression with permutations of
    prefix and/or postfix strings and a comma- or double-dot-separated
    list of strings in braces, resulting in a list of intended strings,
    usually filenames - e.g. expand `echo /mypath/{one,two}` to:

        echo /mypath/one /mypath/two

-   tilde expansion - substitute the path to a user's home directory
    where there is a tilde as the leading character of a word, using the
    text between the tilde and the first colon, slash or whitespace
    character as a username, or the current user if no username is
    present - e.g.  expand `echo ~me/path` to:

        echo /home/me/path

-   parameter and variable expansion - substitute variable or parameter
    (*$1*, *$2* and special parameters) values for composed of a
    dollar-sign followed by a name, or followed by a brace pattern for
    special expansions - e.g. for the assignment `myvar="hello there"`,
    expand `echo "$myvar"` to:

        echo "hello there"

-   arithmetic expansion - calculate an arithmetic expression enclosed
    in a dollar-sign and double-parentheses and substitute its result -
    e.g. expand `echo $(( 1 + 1 ))` to:

        echo 2

-   command substitution - substitute the stdout of a command enclosed
    in a dollar-sign and single-parentheses - e.g. expand `echo "$(cat
    myfile)"` to:

        echo "contents of myfile"

-   word splitting - substitute the results of parameter and variable
    expansions split on any letters in the special IFS variable - e.g.
    for the assignment `myvar="hello there"` and IFS with a space in it (one
    of the defaults along with tab and newline), split `echo $myvar` to:

        echo hello there

    Note that *hello* and *there* above are separate words in the
    result.  Using double-quotes around the variable reference, e.g.
    `"$myvar"`, prevents all forms of expansion and word splitting,
    except variable expansion.  Single-quotes prevent variable expansion
    in addition to the other forms.

-   pathname expansion - expand a path pattern into a list of matching
    directory and filenames, also known as globbing - e.g. `echo ./*`
    expanding to:

        echo ./file1.txt ./file2.txt

-   process substitution - substitute process output as a redirection to
    a command - e.g. `cat <(echo hello)` outputting:

        hello

-   quote removal - remove single- and double-quotes, as well as
    backslashes which are not the result of an expansion

-   command resolution - for each resulting statement, determine whether
    the command to be run exists, in order, as a:

      -   function

      -   built-in command

      -   command in the PATH

    Note that a path included as the start of a command will not
    necessarily force a file to be run, since function names can include
    path characters - e.g. for the function `./myfunc () { echo hello
    ;}`, the command `./myfunc` will end up invoking the function, not a
    script named `myfunc` in the current directory.

    A backslash in front of a command name will, however, prevent alias
    expansion since the backslash will not match the alias, but will be
    stripped before attempting to run the command.

Whew!  That's a lot.  All just to get from `cd ~` to a prompt in your
home directory.

Fortunately we don't have to pay attention to all of these right now.
History expansion, for example, is an interactive feature that isn't of
much use in a script, and so is disabled by default.

So are aliases, although we've found a use for those already, so we will
pay a bit more attention to them.  For the most part we'll discuss the
ones which require you to program carefully, namely the expansions.

Continue with [part 18]

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-24-approach-bash-like-a-developer-part-16-recap                     %}
  [Practical Guide to UNIX for MacOS X Users]: http://www.informit.com/articles/article.aspx?p=441605&seqNum=9
