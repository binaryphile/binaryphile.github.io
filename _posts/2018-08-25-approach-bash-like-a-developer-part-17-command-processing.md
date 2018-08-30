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
that happens?  And the next, and the next?

It can actually be a bit tough to get the full picture, even from fairly
good docs on the web.  The following is compiled from a few different
sources.  Here's one that is particularly enlightening, [from the
developer himself].  There's also a [maintainer's list of steps] which
is good.

Here's what happens, in order:

-   *[history expansion]* - substitute a reference to an older command -
    e.g. if the last command was `echo hello`, expand `!!` to:

        echo hello

-   *[alias substitution]* - substitute a string for the first word of a
    simple command - e.g. for the alias `alias ls='ls -l'`, expand `ls`
    to:

        ls -l

    Aliases can resolve into other aliases, but evaluation stops if it
    resolves into itself, hence no recursion for the alias given here.

-   *lexing/parsing* - identify important syntactical tokens such as
    semicolons, parentheses, braces, pipe and redirection characters and
    determine the grammatical structure of the resulting statement

-   *[brace expansion]* - permute a string with a comma-separated (or
    double-dot-separated) list of strings in braces - e.g. expand `echo
    /mypath/{one,two}` to:

        echo /mypath/one /mypath/two

-   *[tilde expansion]* - substitute the path to a user's home directory
    for a word with a tilde as the leading character, using the text
    between the tilde and the first colon, slash or whitespace character
    as a username, or the current user if there is no such text - e.g.
    expand `echo ~me/path` to:

        echo /home/me/path

-   simultaneously in left-to-right order:

    -   *[parameter and variable expansion]* - substitute variable or
        parameter (*$1*, *$2*, *$@*, etc.) values for a `$name`
        construct (or a `${special_syntax}` construct for [special
        expansions]) - e.g.  for the assignment `myvar="hello there"`,
        expand `echo "$myvar"` to:

            echo "hello there"

    -   *[arithmetic expansion]* - calculate an arithmetic expression
        enclosed in a `$((expression))` construct and substitute its
        result - e.g. expand `echo $((1 + 1))` to:

            echo 2

    -   *[command substitution]* - substitute the stdout of a command
        for a `$(command)` construct - e.g. expand `echo "$(cat
        myfile)"` to:

            echo "contents of myfile"

    -   *[process substitution]* - substitute a system-generated
        filename for a `<(command)` construct, which when opened,
        presents the output of the command as the file contents - e.g.
        `vim <(echo hello)` starting up vim with the file content:

            hello

-   *[word splitting]* - split the results of expansions from the last
    step on any letters in the special IFS variable - e.g.  for the
    assignment `myvar="hello there"` and IFS with a space in it (one of
    the defaults along with tab and newline), split `echo $myvar` to:

        echo hello there

    Note that *hello* and *there* above are separate words in the
    result.

-   *[pathname expansion]* - expand a path pattern into a list of
    matching directory and filenames, also known as *globbing* - e.g.
    expand `echo ./*` to:

        echo ./file1.txt ./file2.txt

-   *[quote removal]* - remove any of the types of quotation marks, as
    well as backslashes (which are not the result of an expansion)

-   *[command resolution]* - for each resulting statement, determine
    whether the command to be run exists, in order, as a:

      -   function

      -   built-in command

      -   command in the path

Whew!  That's a lot.  All just to get from *cd ~* to a prompt in your
home directory.

Guess what, I lied, there's more!  Here are even more [details on command
execution] once the command is determined.  Hooboy!

Fortunately we don't have to pay attention to all of these.  History
expansion, for example, is an interactive feature that isn't of much use
in a script, and so is disabled by default.

For the most part we'll discuss the ones which require you to program
carefully, namely the word-splitting and the expansions.

Continue with [part 18] - word splitting

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-24-approach-bash-like-a-developer-part-16-recap                     %}
  [from the developer himself]: http://aosabook.org/en/bash.html
  [maintainer's list of steps]: http://wiki.bash-hackers.org/scripting/bashbehaviour#posix_run_mode
  [history expansion]: https://www.gnu.org/software/bash/manual/html_node/History-Interaction.html
  [alias substitution]: https://www.gnu.org/software/bash/manual/html_node/Aliases.html
  [brace expansion]: http://wiki.bash-hackers.org/syntax/expansion/brace
  [tilde expansion]: http://wiki.bash-hackers.org/syntax/expansion/tilde
  [parameter and variable expansion]: http://wiki.bash-hackers.org/syntax/pe
  [special expansions]: http://wiki.bash-hackers.org/syntax/pe#overview
  [arithmetic expansion]: http://wiki.bash-hackers.org/syntax/expansion/arith
  [command substitution]: http://wiki.bash-hackers.org/syntax/expansion/cmdsubst
  [process substitution]: http://wiki.bash-hackers.org/syntax/expansion/proc_subst
  [word splitting]: http://wiki.bash-hackers.org/syntax/expansion/wordsplit
  [pathname expansion]: http://wiki.bash-hackers.org/syntax/expansion/globs
  [quote removal]: http://wiki.bash-hackers.org/syntax/quoting
  [command resolution]: http://wiki.bash-hackers.org/syntax/grammar/parser_exec#simple_command_execution
  [details on command execution]: http://wiki.bash-hackers.org/syntax/grammar/parser_exec
  [part 18]:      {% post_url 2018-08-31-approach-bash-like-a-developer-part-18-word-splitting            %}
