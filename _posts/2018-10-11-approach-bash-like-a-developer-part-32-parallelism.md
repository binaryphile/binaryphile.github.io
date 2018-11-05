---
layout: post
title:  "Approach Bash Like a Developer - Part 32 - Parallelism"
date:   2018-10-11 01:00:00 +0000
categories: bash
---

This is part 32 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed enhancing our option parsing with *getopt*.
This time, let's talk about parallelism in bash.

Let's work by example this time.  A good example of a task suitable for
bash might be to monitor a directory and perform a task when a
particular type of file shows up.

Let's start with our basic template.  Before we can add any
functionality, we'll write tests, but we've got the skeleton already:

{% highlight bash %}
#!/usr/bin/env bash

set -o noglob

source $(dirname $(readlink -f $BASH_SOURCE))/support.bash
IFS=$'\n'       # we're going to use newline this time

main () {
  :
}

sourced? && return
strict_mode on

main $@
{% endhighlight %}

There's some other boilerplate we can get out of the way as well.  Along
with our option parsing, we also need to tell users how to use our
script.

The easiest way to create a multiline message in bash is with a
[heredoc].  Heredoc's aren't very picturesque though.  They interrupt
the indentation flow of code.  So let's make it so we can indent a
heredoc and have it automatically de-dented for us.

The first detail is that heredoc's have an end marker:

{% highlight bash %}
cat <<END
Here's a
multiline message.
END
{% endhighlight %}

The end marker, here *END*, has to be at the beginning of the line.
Also, expansions happen within the text, which sometimes we don't want.

If you don't need expansions, there's a neat trick you can use to indent
the end marker.  If the end marker specification at the start of the
heredoc has either kind of quotes around it, it doesn't do expansions.
It also allows the end marker to have spaces in front of it:

{% highlight bash %}
# left margin
  cat <<'  END'
    Here's a
    multiline message.
  END
# left margin
{% endhighlight %}

This is more like what our code looks like, and the end marker works
correctly with two spaces in front of it.  However, the heredoc has all
four leading spaces included, which isn't what we'd like normally.

Let's start with a function to store a heredoc in a named variable:

{% highlight bash %}
describe get_heredoc
  it "stores a heredoc in a named variable"
    get_heredoc sample <<'    END'
      sample text
    END
    assert equal "      sample text" $sample
  ti
end_describe
{% endhighlight %}

The leading spaces in the test value of the assert statement are because
of the indentation on the heredoc itself.

{% highlight bash %}
get_heredoc () {
  ! IFS=$'\n' read -rd '' $1
}
{% endhighlight %}

*read* takes the heredoc into our variable name.  The *-d* argument
sets the read delimiter to be null instead of newline, allowing it to
read multiple lines.

The *-r* option ensures that escape sequences in the string aren't
interpreted.

The *IFS* setting allows the trailing newline of the heredoc to be
trimmed before being stored in the variable.  It allows leading and
trailing spaces on the value, however, which normally are trimmed by the
default *IFS*.

Since it's part of the command, the *IFS* set here only affects the
environment of the command.  The *IFS* variable in our shell is
unchanged.

Since *read* returns a false at the end of input (which is always the
case with a heredoc), we negate it to prevent triggering *errexit*.
*read* returns false so it can be used as the condition in a *while*
loop.

Now let's handle the indentation with another function:

{% highlight bash %}
describe get
  it "stores a heredoc in a named variable"
    get sample <<'    END'
      sample text
      line 2
    END
    assert equal $'sample text\nline 2' $sample
  ti
end_describe
{% endhighlight %}

This one gets the shorter name because it's the more useful function.

We'll trim the indentation based on the indent of the first line:

{% highlight bash %}
get () {
  local -n heredoc_=$1
  local indent_

  get_heredoc heredoc_
  indent_=${heredoc_%%[^[:space:]]*}
  heredoc_=${heredoc_#$indent_}
  heredoc_=${heredoc_//$'\n'$indent_/$'\n'}
}
{% endhighlight %}

The indent is gotten by trimming the largest set of trailing characters
which start with a non-space.  The indent is then trimmed off the start
of the heredoc. Finally, every newline which is followed by the indent
is substituted with a newline by itself, no indent.

Now that we've got our heredoc getter, let's get back to the outline:

{% highlight bash %}
#!/usr/bin/env bash

set -o noglob

source $(dirname $(readlink -f $BASH_SOURCE))/support.bash
IFS=$'\n'

Prog=$0

get Usage <<END
  Monitor a directory and copy files to a server

  Usage: $Prog [option] DIRECTORY PATTERN[|PATTERN|...] REMOTE

  Options:
    -p PERIOD     number of seconds between checks (default: 360)

  Arguments:
    DIRECTORY     the directory to check

    PATTERN       file pattern of files to transfer.  multiple patterns
                  can be separated with the vertical bar |

    REMOTE        remote location in [<user>@]<server>:<directory>
                  format

  Check a directory for new files matching a file pattern (or patterns)
  every PERIOD seconds.  When new files are found, transfer them to a
  remote location.
END

main () {
  :
}

sourced? && return
strict_mode on

main $@
{% endhighlight %}

We've got an outline and a usage message.  The message is key because it
gives us a solid view of our objective as well as our option parsing
requirements.

Before we spell out the option parsing parameters, though, let's get
started with tests and the basic functions we know we'll need.

Also, I'm cheating by looking forward to the answer I already have in
mind, but I'm going to switch the *IFS* separator to newline in this
script.  Occasionally I choose newline instead of the unit separator
when I know I'll be working with pipelines and command-line utilities,
which are the primary tools for accomplishing parallelism in bash.

Using newline for the separator means we'll have to be careful to quote
any variable expansion for a variable which contains newlines.  Our
usage message is one such variable.

Let's start with a simple piece of functionality that we know we'll
want:

{% highlight bash %}
describe list
  alias setup='dir=$(mktemp -d) || return'
  alias teardown='rm -rf $dir'

  it "lists files matching a pattern list separated by newlines"
    touch $dir/file.txt $dir/file.html $dir/file.csv
    result=$(list $dir '*.txt|*.html')
    assert equal $'file.html\nfile.txt' "$result"
  ti
end_describe
{% endhighlight %}

We know we'll need the contents of the directory, so that we can compare
what's changed when we check again later.

We're going to use a file glob pattern to specify the filenames.
However, alternate filetypes aren't supported by normal globs.  The pipe
symbol as an alternator between file globs is a feature of *case*
statements and [extended globs]:

{% highlight bash %}
list () { (
  cd $1
  shopt -s nullglob
  shopt -s extglob
  set +o noglob
  eval "set -- +($2)"
  echo "$*"
) }
{% endhighlight %}

We're using a glob here, which means we have to turn globbing back on.
In addition, if the directory is empty, a glob won't evaluate and will
instead just give back the pattern itself, which is undesirable.  In
that case, you have to turn on *nullglob* in order for it to evaluate to
an empty string.

*extglob* is the setting which turns on extended globbing. The format to
match one or more patterns is *+(PATTERN_LIST)*.  Since we're provided
the pattern list when called, we add the *+()* portion in the
expression.

Unfortunately, if *extglob* isn't turned on when the function is being
defined, the parser won't even let you use the opening parenthesis. So
to defer evaluation until the function has had a chance to execute and
*extglob* to be set, we have to use an *eval*.

In order to make these changes, as well as cd to the directory, it's
easiest to make them in a subshell.  That way we don't have to undo them
afterward.  You can actually use parentheses instead of the braces
surrounding the function body in its definition and that will execute
the entire function in a subshell.

I tend not to drop the braces because it's easy to visually miss the
change from braces to parentheses, which makes the code harder to
comprehend.  Instead I use the parentheses inside the braces, separated
by a space to make it visually conspicuous.

The test passes, so let's try another:

{% highlight bash %}
describe newitems
  it "outputs a newline-separated list of items which appear in a second list but aren't in the first"
    result=$(newitems $'apple\nbanana\ncherry' $'apple\ndate\nelderberry')
    assert equal $'date\nelderberry' "$result"
  ti
end_describe
{% endhighlight %}

We're taking the items which are in the second newline-separated list
which aren't in the first.  These are the files which will be new in the
second directory listing after the first, and the ones which we'll want
to transfer.

{% highlight bash %}
newitems () {
  comm -13 <(echo "$1") <(echo "$2")
}
{% endhighlight %}

There's a command-line tool *[comm]* which determines the common or
different lines between two sorted files.  We can tell it to return the
new lines in the second file and use [process substitution] to make our
lists appear as files to the command.

*newitems* is basically a simple wrapper around *comm*, but it does hide
the syntax for converting the strings into files, which makes our code
look nicer.  However, unlike most of the functions we've written so far,
this one only returns a value on stdout.  The input is expected to be
newline-separated, and so is the output.  Most linux tools which process
lists handle them on a newline basis.

This means that chaining such commands together in pipelines is easy,
you just connect stdout from one command to stdin of the other. It also
means that the commands are executed in parallel, one feeding the next
but in separate processes. Finally, it also means that using newline as
the *IFS* separator ends up being more natural if you need to process
these lists as arrays at any point.

The originating command can feed items at its own pace, depending on how
it's generating its list.  For example, it could be monitoring a
physical process like a chemical reaction and generating events based on
when things happen.

If commands further down the pipeline take more time than the command
generating their input, the pipeline buffers the items in progress until
the receiving command is ready for them.

There is one unfortunate edge case with *comm*, however.  Normally, if
it has nothing new to tell you about, it doesn't output anything and the
rest of the pipeline is not triggered.  When the first list has items
and the second list is empty, however, it outputs an empty string
instead, which does trigger the pipeline.  That ends up causing an error
with the next function in the pipeline, which is expecting a filename.

We'll write a test for this too:

{% highlight bash %}
it "doesn't report anything when the second list is empty and the first isn't"
  result=$(newitems one '' | while read -r item; do echo triggered; done)
  assert equal '' "$result"
ti
{% endhighlight %}

This one is tricky to test for because an empty string is the normal
result type for our *result* assignment, but in this case, there's a
difference between a null answer result and an empty string result.
Recreating the pipeline is the only way to test.

Here's the fix:

{% highlight bash %}
blank? () {
  [[ -z ${1:-} ]]
}

newitems () {
  blank? $2 && return
  comm -13 <(echo "$1") <(echo "$2")
}
{% endhighlight %}

Next we'll write a function which takes items from a pipeline:

{% highlight bash %}
describe transfer
  it "calls scp"
    stub_command scp 'echo $@'

    result=$(transfer dir dest <<<$'one.txt\ntwo.txt')
    assert equal $'dir/one.txt dest\ndir/two.txt dest' "$result"
  ti
end_describe
{% endhighlight %}

And the code:

{% highlight bash %}
transfer () {
  local file

  while read -r file; do
    scp $1/$file $2
  done;:
}
{% endhighlight %}

Since we're processing from stdin, we use *read*. It reads a line at a
time, looping until there's no longer input.  This is how you write a
function which receives items in a pipeline.  When the input ends,
*read* returns false and the loop is broken.

The finish of the loop will therefore be a false.  That's not a problem
for *errexit*, since *while* suspends *errexit* for its expression.

However, since there aren't any other commands in the function, the
return code from the function will also be false. This *does* trigger
*errexit* in the caller, so we've added *;:* after the loop to prevent
that.

With that, we've got the pieces for our main function:

{% highlight bash %}
main () {
  local new_contents
  local old_contents

  # this won't work yet without our options
  old_contents=$(list $dir $pattern_list)
  while true; do
    sleep $period
    new_contents=$(list $dir $pattern_list)
    newitems "$old_contents" "$new_contents"
    old_contents=$new_contents
  done | transfer $dir $dest;:
}
{% endhighlight %}

I typically don't test *main* and keep it simple, relying on the unit
tests for the functions we've written to verify correctness.  We can
always test it if it gets complicated, or refactor it into something
simpler which tests any new functions.

Our *main* here runs a permanent loop (*while true*) that sleeps for the
defined amount of time, then lists the directory.  It keeps the
pre-sleep directory listing in the *old_contents* variable and the
updated one in *new_contents*.  The first time through the loop, it
pre-lists the directory before the first *sleep*.

The pipeline after the *done* in the *while* loop receives the entirety
of the output generated by any statement within the loop.  In our case,
that's just the *newitems* call, which is what we want.

There is a temptation to put the pipeline directly on the *newitems*
command, e.g. *newitems "$old_contents" "$new_contents" | transfer $dir
$dest"*.  However, that changes things in a way we don't want...it's
better to have the pipeline on the outside of the while loop.

The reason for this is how parallelism works in bash.  If the pipeline
is on the inside of the while loop, the loop will have to wait until
they are both done before iterating, meaning that the transfers which
take some time will cause the loop to pause.  When the loop comes around
again, it will then sleep the full period on top of how long it was
paused, which could be very different than what we've led the user to
expect.

If the pipeline is on the outside of the loop, as shown above, then it
will operate independently of the transfers.  That's exactly what we
want.  On the producer side of the pipeline, the main loop will check
the directory and feed the names down the pipe, without waiting for
anything else.  Since that takes almost no time, it will iterate again
and then wait the sleep period before it sends more names down the pipe.
This means it will loop precisely once per period as the user expects.

On the consumer side of the pipeline, the transfer process will read a name
at a time from the pipe and transfer the file, then read the next and so
on.  If there are no names, it will simply wait until more are produced.
If there are more names than it can process at once (i.e. more than one
name at a time, since that's all it transfers), then the pipeline will
buffer them until the transfer loop is ready to read the next.

The producer and consumer will be looping independently of each other
and processing at their own rates, and that's exactly what we want with
parallel processes.

Now some finishing touches about usage, options and passing them to
*main*:

{% highlight bash %}
#!/usr/bin/env bash

set -o noglob

source $(dirname $(readlink -f $BASH_SOURCE))/support.bash
IFS=$'\n'

Prog=$0

get Usage <<END
  Monitor a directory and copy files to a server

  Usage: $Prog [option] DIRECTORY PATTERN[|PATTERN|...] REMOTE

  Options:
    -p PERIOD     number of seconds between checks (default: 300)
    --help        show this message and exit
    --version     show the version number and exit

  Arguments:
    DIRECTORY     the directory to check
    PATTERN       file pattern of files to transfer.  multiple patterns
                  can be separated with the vertical bar |
    REMOTE        remote location in [<user>@]<server>:<directory>
                  format

  Check a directory for new files matching a file pattern (or patterns)
  every PERIOD seconds.  When new files are found, transfer them to a
  remote location.
END

declare -i Period=5*60
Version=0.0.1

Help_flag=0
Trace_flag=0
Version_flag=0

main () {
  local dir=$1
  local pattern_list=$2
  local dest=$3
  local new_contents
  local old_contents

  old_contents=$(list $dir $pattern_list)
  while true; do
    sleep $Period
    new_contents=$(list $dir $pattern_list)
    newitems "$old_contents" "$new_contents"
    old_contents=$new_contents
  done | transfer $dir $dest;:
}

list () { (
  cd $1
  shopt -s nullglob
  shopt -s extglob
  set +o noglob
  eval "set -- +($2)"
  echo "$*"
) }

newitems () {
  blank? $2 && return
  comm -13 <(echo "$1") <(echo "$2")
}

transfer () {
  local file

  while read -r file; do
    scp $file $1
  done;:
}

sourced? && return
strict_mode on

Option_defs=(
  -p,Period
  --help,Help_flag,f
  --version,Version_flag,f
  --trace,Trace_flag,f
)
parseopts "$*" "${Option_defs[*]}" Options Posargs
(( ${#Options[@]}                   )) && declare ${Options[@]}
(( Help_flag || ${#Posargs[@]} != 3 )) && die "$Usage"
(( Version_flag                     )) && die "$Prog version $Version"
(( Trace_flag                       )) && set -x

main $Posargs
{% endhighlight %}

This is the finished version of our (simple) tool.

Here we've added code to:

-   define and parse the options detailed in the usage message

-   print help and exit

-   print the version number and exit

-   define the default period and override it if the user specifies the
    option

When you run it, you'll need to send it a Ctrl-C interrupt or
termination signal to stop it.  Add tracing with the undocumented
*`--trace`* flag to see its operation in detail while it runs.

For bonus points, here's a version which implements a lockfile and also
checks to see if the file to be copied is in use by another process
before trying to copy it (for example, if it's mid-copy or download).
It also tracks which files it has already transferred, issues tracebacks
on errors but continues running unless it experiences too many errors in
a short amount of time, etc., etc.:

{% highlight bash %}
#!/usr/bin/env bash

set -o noglob

source $(dirname $(readlink -f $BASH_SOURCE))/support.bash
IFS=$'\n'

Prog=$0

get Usage <<END
  Monitor a directory and copy files to a server

  Usage: $Prog [option] DIRECTORY PATTERN[|PATTERN|...] REMOTE

  Options:
    -p PERIOD     number of seconds between checks (default: 300)
    --help        show this message and exit
    --version     show the version number and exit

  Arguments:
    DIRECTORY     the directory to check
    PATTERN       file pattern of files to transfer.  multiple patterns
                  can be separated with the vertical bar |
    REMOTE        remote location in [<user>@]<server>:<directory>
                  format

  Check a directory for new files matching a file pattern (or patterns)
  every PERIOD seconds.  When new files are found, transfer them to a
  remote location.
END

Lockfile=/dev/shm/$Prog-lockfile
Processedfile=/tmp/$Prog-transferred

declare -i Period=5*60
Version=0.0.1

Help_flag=0
Trace_flag=0
Version_flag=0

main () {
  touch $Dir/$Processedfile

  echo "started at $(date)"
  start_monitor
}

append_file () {
  cat >>$1
}

busy? () {
  fuser $Dir/$1 &>/dev/null
}

list () { (
  cd $1
  shopt -s nullglob
  shopt -s extglob
  set +o noglob
  eval "set -- +($2)"
  echo "$*"
) }

lockfile? () {
  ! (set -o noclobber; write_file $Lockfile <<<$$) 2>/dev/null
}

newitems () {
  blank? $2 && return
  comm -13 <(echo "$1") <(echo "$2")
}

not_busy () {
  local file

  while read -r file; do
    ! busy? $file && echo $file
  done;:
}

not_transferred () {
  local file

  while read -r file; do
    ! transferred? $file && echo $file
  done;:
}

running? () {
  [[ -e $Lockfile ]] && ps -p $(<$Lockfile) >/dev/null
}

singleton? () {
  ! running?    || return
  rm $Lockfile  || return
  ! lockfile? && trap "rm $Lockfile;"' echo "stopped at $(date)"' EXIT
}

start_monitor () {
  local new_contents
  local old_contents

  old_contents=$(list $Dir $Pattern_list)
  while true; do
    sleep $Period
    new_contents=$(list $Dir $Pattern_list)
    newitems "$old_contents" "$new_contents" | not_busy | not_transferred
    old_contents=$new_contents
  done | transfer;:
}

track () { (
  cd $Dir
  md5sum $1 | append_file $Processedfile
) }

transfer () {
  local file

  while read -r file; do
    scp $Dir/$file $Remote
    track $file
  done;:
}

transferred? () { (
  cd $Dir
  grep -q $(md5sum $1) $Processedfile
) }

write_file () {
  cat >$1
}

sourced? && return

Option_defs=(
  -p,Period
  --help,Help_flag,f
  --version,Version_flag,f
  --trace,Trace_flag,f
)
parseopts "$*" "${Option_defs[*]}" Options Posargs
(( ${#Options[@]}                   )) && declare ${Options[@]}
(( Help_flag || ${#Posargs[@]} != 3 )) && die "$Usage"
(( Version_flag                     )) && die "$Prog version $Version"

singleton? || die "another instance is running.  quitting."

(( Trace_flag )) && set -x

set -- $Posargs
Dir=$1
Pattern_list=$2
Remote=$3

SECONDS=0
for (( retries = 0; retries < 10; retries++ )); do
  (
    strict_mode on
    main
  )
  echo "restarting after error"
  (( SECONDS >= 24*60*60 )) && retries=0
  SECONDS=0
  sleep 10
done

echo "too many retries, exiting"
exit 1
{% endhighlight %}

Continue with [part 33] - modules

  [part 1]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
  [Last time]: {% post_url 2018-10-08-approach-bash-like-a-developer-part-31-getopt %}
  [heredoc]: http://wiki.bash-hackers.org/syntax/redirection#here_documents
  [comm]: https://linux.die.net/man/1/comm
  [process substitution]: http://wiki.bash-hackers.org/syntax/expansion/proc_subst
  [extended globs]: http://wiki.bash-hackers.org/syntax/pattern#extended_pattern_language
  [part 33]: {% post_url 2018-10-16-approach-bash-like-a-developer-part-33-modules %}
