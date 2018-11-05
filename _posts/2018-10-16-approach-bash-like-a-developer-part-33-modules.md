---
layout: post
title:  "Approach Bash Like a Developer - Part 33 - Modules"
date:   2018-10-16 01:00:00 +0000
categories: bash
---

This is part 33 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed parallelism and made a service in bash. This
time, let's talk about modules and the role they play in other
languages, and how to approximate them in bash.

Most modern languages have package or module systems, including python,
ruby, go, java and others. Modules exist primarily to manage namespaces.

Within a module, code is able to refer to global variables, constants
and functions/classes without any namespace qualifier. Outside the
module, the same things can only be referenced by importing/requiring
the module, and usually only if the module specifies that the items are
available outside itself.

When I say global variables, that's a slight misnomer since a module's
globals aren't global to the rest of the program. Code which imports the
module doesn't get the module's globals in its global namespace. Those
variables, if available at all, become available by qualifying them with
the namespace of the module.

Modules can even be hierarchical, allowing other namespaces to be nested
inside themselves.

The details of modules differ from language to language, especially how
they map to files and how they control visibility. But in general, most
languages do share the following attributes:

-   from within the module, functions and variables are referenced
    without qualification

-   some or all functions and variables are visible from outside the
    module when the module is imported

-   items are referenced with the module's name as a qualifier,
    typically a prefix separated by a dot. alternatively, the language
    provides a means to map items directly into the current namespace.

-   the module can provide initialization code which is executed when
    the module is imported

-   the module is only loaded and initialized once, even it is imported
    multiple times

-   modules may be nested hierarchically and the initialization code of
    the parent is run when initializing a child module

-   the module system follows an algorithm for finding standard modules
    and third-party modules in the filesystem

So how to approximate this in bash?

Bash's only similar function is *source*, but it's not very similar at
all. It does have an algorithm for finding files in the filesystem (the
PATH), and it can run initialization code when it sources a file
(anything outside a function definition is run when sourced), but that's
where the similarity ends.

There is no namespacing, no method to ensure that modules are only
loaded once and no hierarchical nesting.

The biggest difference is namespacing. All functions and global
variables in the sourced file are loaded into the global namespaces
along with everything else. There is only one function namespace and one
variable namespace. Nothing is qualified.

Let's presume for the moment that the two similarities (initialization
and the file-finding algorithm) are sufficient for our purposes.

Let's also assume that a hierarchical structure for modules is more than
we need to worry about right now and that a single level is sufficient.

That leaves two things. First, that modules shouldn't be reloaded if
imported more than once. Second, that functions and variables should be
available by qualifying references to them with the namespace of their
module. We'll also skip worrying about fine-grained access control to
the module's functions and variables and just assume everything is
visible.

Import Once
-----------

Let's consider singular importation first. There's nothing about the
*source* command which will stop you from running a file's code twice if
you source it twice.

The only way you can track whether a file has been sourced is to use a
global variable. You could either create a flag for each file loaded, or
use a hash or array to store the names of the loaded files. It makes
sense to use a hash with the names of the loaded files as keys, both for
performance as well as to keep the global namespace clean.

We'll use a hash named *\_modules\_*. I reserve all the variables
beginning and ending with underscore as my own personal namespace for
purposes such as this.

We'll use the name *module* for the library which will implement the
functionality. We'll leave off the *.bash* extension since we'll be
using it more like a command than a library.

*shpec/module\_shpec.bash:*

{% highlight bash %}
IFS=$'\n'
set -o noglob

Dir=$(dirname $(readlink -f $BASH_SOURCE))/..
source $Dir/shpec/shpec-helper.bash
cd $Dir/lib

describe module
  alias setup='dir=$(mktemp -d) || return'
  alias teardown='rm -rf $dir'

  it "stores a module in a global hash"
    touch $dir/sample.bash
    source module $dir/sample.bash
    [[ -v _modules_[$dir/sample.bash] ]]
    assert equal 0 $?
  ti
end_describe
{% endhighlight %}

The setup and teardown handle giving us a temporary location. The call
to *source* tells it to load our file. Any further arguments are passed
to the file as positional arguments.

We'll store the filename as the key to the hash. Since multiple files
can have the same filename, we'll store the path (including filename) as
the differentiator.

While we're using the full path *$dir/sample.bash*, which prevents
*source* from looking through PATH to find the file, we're not providing
a path to *module*.

While it would be nice to use a path to *module* as well to ensure that
we get the right one, I've preferred not qualifying it with a path so
that the command reads better.  Since I don't actually have another
*module* on my PATH, it will find *module* in the local directory after
it's finished searching the PATH.  We have to keep in mind that this
could bite us if there ever is another *module* on the PATH.

We saw the [-v test] in an earlier post. It verifies that the key exists
in the hash.

*lib/module:*

{% highlight bash %}
#!/usr/bin/env bash
# above is a hint to editors since we aren't using the .bash extension

declare -A _modules_

_modules_[$1]=''
{% endhighlight %}

As mentioned, the arguments following *module* are passed in as
positional arguments, so *$1* is *$dir/sample.bash*.

Here we declare the hash and create the key. The value doesn't matter
since all we're testing for is the existence of the key.

Another test:

{% highlight bash %}
it "sources the file"
  echo 'echo hello' >$dir/sample.bash
  result=$(source module $dir/sample.bash)
  assert equal hello "$result"
ti
{% endhighlight %}

This one is pretty self-explanatory.

{% highlight bash %}
#!/usr/bin/env bash

declare -A _modules_

source $1         # new
_modules_[$1]=''
{% endhighlight %}

Again, no surprises here.

Test:

{% highlight bash %}
it "doesn't source it twice"
  echo 'echo hello' >$dir/sample.bash
  result=$(
    source module $dir/sample.bash
    source module $dir/sample.bash
  )
  assert equal hello "$result"
ti
{% endhighlight %}

This is the goal for this part of the implementation, to prevent
double-sourcing.

{% highlight bash %}
#!/usr/bin/env bash

declare -A _modules_

[[ -v _modules_[$1] ]] && return  # new
source $1
_modules_[$1]=''
{% endhighlight %}

A simple test for the existence of the key tells the implementation to
bail out if the file has already been loaded.

It doesn't matter that the declaration of *\_modules\_* occurs both
times that *module* is called because we aren't assigning a value, in
which case *declare* doesn't mess with the existing instance of
*\_modules\_*.

All right, now we have the first part handled. The second part is the
namespacing of the functions and variables of the module when it is
imported.

Modulizing Variables
--------------------

I'll start with the module's global variables. The tl;dr is this: I
don't have a way to do it in an automated fashion, i.e. a method to
convert non-namespaced variables to namespaced variables when they are
sourced.

If you want to namespace your variables, you'll need to do so manually
when you write your code. I don't have a way to namespace variables
which belong to third-party code.

You'll have to use the namespaced versions in both your module as well
as the code which imports it. That's unfortunate since it's not the
point of the module system. Modules are supposed to make it easy to
reference the variables from within the module, without the need for
qualification.

To namespace your variables, you could either use a pre/postfix name,
such as the module's name. Or you could use a hash named for the module,
with keys representing the variables. Either works, but I suggest using
a prefix with the module's name since it doesn't need the visually noisy
braces of a hash to reference it.

Of course, a dot isn't a legal character for a variable identifier, so
underscore has to do in its place. For example, if I had a module named
*foo*, then any globals I wanted to declare might be named something
like *foo\_myvar*. If it were a constant, I might name it *foo\_Myconst*
in keeping with the capitalization method for constants.

While this is disappointing, the one sunny spot is that variables are
usually the least of what you're looking for with a module. It's really
more about the functions. And I do have good news in that regard.

Modulizing Functions
--------------------

Fortunately, it's easier to namespace functions than it is to namespace
variables.

Let's review the challenge posed by trying to automate the namespacing
of a bash source file.

We want to take a file which defines a number of functions and source
its code, while also changing the names of all of those functions to
have a prefix. The prefix is the name of the module, and it is separated
from the original function name by a dot.

In it's simplest incarnation, the target file would only contain
function definitions. Those functions would all be imported by the
caller, with no need to selectively exclude any of them. They also would
not call any of the functions in their own file. Therefore, all we'd
need to do would be to modify the function names as they are defined.

Since the functions in the calling file might overlap with the names of
the functions defined in the module, we want to make sure that the
functions are never imported without the qualifier so they never have a
chance to overwrite our functions. We want a strict separation between
the current namespace and the module's.

Fortunately, bash allows functions to have dots in their name (although
it's not officially encouraged). One way to accomplish our goal would be
to pass the file through *sed* as we source it, looking for patterns
that match the definition of a function and applying the prefix prior to
the actual sourcing.

Without actually figuring out the pattern, that technique would look
something like this:

{% highlight bash %}
source <(sed -r 's/(pattern)/$prefix.\1/g' $import_file)
{% endhighlight %}

That would be sufficient to handle function definitions, with some minor
edge case problems. The pattern would need to recognize the two versions
of function definitions, the one with just the function name followed by
parentheses, e.g. *myfunc ()*, as well as the one using the *function*
keyword, e.g. *function myfunc*. Both forms come at the beginning of a
command, which means either after a newline or a semicolon, perhaps
after some whitespace.

That's fairly easy to turn into a regular expression, but it's not good
enough to recognize the actual syntactic structure of the language. For
example, it would match something which looks like a function definition
which is actually part of a multiline string, for example.

It breaks down further when we consider some of the other complexities
beyond the simplest case. For example, when we consider that imported
functions may have dependencies on (that is, they may call) other
functions in the module, that means that function calls have to be
substituted as well as definitions.

That's another pattern, but this time we need to know the names of the
functions we're looking for. Each invocation needs to be identified and
prefixed if it's at the beginning of a line or after a semicolon. Again,
it's susceptible to substituting things which look like invocations that
syntactically aren't, but it should mostly work.

As you can see, that approach is somewhat fragile and entails generating
some potentially challenging expressions.

A better solution would involve parsing the file so that we understood
the grammar and only substituted the correct parts of the syntax tree.
The only way to do that would be to have a bash parser and a means for
substituing commands with other text...now that I think of it, though,
we do have those things, don't we?

That's what aliases do, they integrate with the bash parser and
substitute other strings for things which are syntactically identified
as commands. Could they be applied to solve this problem?

The first question is, what would we alias? Let's say that we have a
script we're writing, and we want to import another library called
*foo*. It defines a function *bar*. We import *foo* with our module
functionality. If the import method tries to do its magic by defining an
alias *foo.bar=foo*, it won't really work.  We can call *foo.bar* and
the original function *bar* will be called.

That's not what we want. We haven't separated namespaces, since *bar* is
still imported as is and is still being called without qualification,
which defeats the purpose of the import.

How about if the importer instead defines an alias for *bar* which calls
*foo.bar*? Well, that doesn't work either, since there's no *foo.bar* to
call, and we're trying to get rid of the *bar* function, not call it via
an alias.

It looks hopeless unless we revert back to some form of a *sed* command,
since the function itself must be qualified with the module name.

At this point, I'll take one last look at what [the documentation] has
to say about aliases:

> The rules concerning the definition and use of aliases are somewhat
> confusing. Bash always reads at least one complete line of input
> before executing any of the commands on that line. Aliases are
> expanded when a command is read, not when it is executed. Therefore,
> an alias definition appearing on the same line as another command does
> not take effect until the next line of input is read. The commands
> following the alias definition on that line are not affected by the
> new alias. This behavior is also an issue when functions are executed.
> Aliases are expanded when a function definition is read, not when the
> function is executed, because a function definition is itself a
> command. As a consequence, aliases defined in a function are not
> available until after that function is executed. To be safe, always
> put alias definitions on a separate line, and do not use alias in
> compound commands.

It's true that this is somewhat confusing, but the explanation given
really doesn't do much to help with that. It could really afford to be
teased out into different concepts and explored more deeply.  That's not
what I'm going for here, though.

That complaint aside, the part which sticks out to me is this:

> Aliases are expanded when a function definition is read, not when the
> function is executed, because a function definition is itself a
> command.

What does that really mean?

It means that the time at which the function definition is sourced is
what matters when applying an alias. If an alias exists when the
function is defined, then any commands within the function which
correspond to that alias get expanded at that time. For example,
consider the following code:

{% highlight bash %}
shopt -s expand_aliases
alias bar=baz

foo () {
  bar
}

type foo
{% endhighlight %}

This is its ouptut:

{% highlight bash %}
foo is a function
foo ()
{
    baz
}
{% endhighlight %}

The function definition itself has been changed! This means that the
alias isn't necessary at all when the function is executed, just when
defined.  That's not everything we're looking for, but it *is* part of
the problem we've identified.

Hmm. *The function definition is itself a command.* But what command is
it? Is it the name of the function itself, before the function is even
defined? What command could it be?

{% highlight bash %}
shopt -s expand_aliases
alias bar=foo.bar
alias baz=foo.baz

bar () {
  baz
}

unalias -a   # all aliases

type bar
echo
type foo.bar
{% endhighlight %}

Output:

{% highlight bash %}
type: bar: not found

foo.bar is a function
foo.bar ()
{
    foo.baz
}
{% endhighlight %}

Holy switcheroos, batman! The function name *is* a command, even while
it's being defined! That's how the alias has been applied to the name of
the function definition itself, as we can see from the resulting
listing. *bar* is nowhere to be found...this is full namespacing!

And look what else, the call to *baz* has been replaced with *foo.baz*
as well. Well, we've already seen that in action, so it's no surprise,
but here we see it used for our purpose, to qualify the calls between
functions within the module.

Let's not waste any time. Let's take the brand new, whiz-bang, patented
Lilley technique(TM) for a spin!

Well, we need one thing before we can do that. We need to know what
functions are defined in the file so we can create aliases for them all
before actually sourcing the file.

{% highlight bash %}
IFS=$'\n'
set -o noglob

Dir=$(dirname $(readlink -f $BASH_SOURCE))/..
source $Dir/shpec/shpec-helper.bash
cd $Dir/lib
source ./module ''  # new

in? () {
  [[ $IFS$1$IFS == *"$IFS$2$IFS"* ]]
}

describe _functions_
  alias setup='dir=$(mktemp -d) || return'
  alias teardown='rm -rf $dir'

  it "lists all functions in a file"
    echo 'myfunc () { :;}' >$dir/sample.bash
    result=$(_functions_ $dir/sample.bash)
    in? "$result" myfunc
    assert equal 0 $?
  ti
end_describe
{% endhighlight %}

*\_functions\_* lists the functions defined in the module we want to
load.  For the moment, we're just checking that it lists *myfunc* from
the sample file, but it may also list other things as well.  We'll get
to that.

{% highlight bash %}
_functions_ () {
  source $1
  compgen -A function
}
{% endhighlight %}

*compgen* is a part of bash which helps with bash completion, but in
this case we're taking advantage of its ability to list all defined
functions.

{% highlight bash %}
it "doesn't list any other functions"
  echo 'myfunc () { :;}' >$dir/sample.bash
  result=$(_functions_ $dir/sample.bash)
  assert equal myfunc "$result"
ti
{% endhighlight %}

Let's tighten this up a bit...the earlier version listed *myfunc* but
also returned every other defined function. Let's limit it to the
functions defined in the file.

{% highlight bash %}
_functions_ () {
  env -i bash <<END
    source $1
    compgen -A function
END
}
{% endhighlight %}

The *env* command manipulates the shell context prior to running the
command given as an argument.  The *-i* option clears all functions and
variables.

By telling it to run bash in a clean environment, we can ensure that we
only return what is sourced in the target file.  Since we have to run a
command with *env*, we can make it be another bash instance which takes
our commands on stdin from a heredoc.

{% highlight bash %}
  it "doesn't list functions from a sub-source"
    cat <<END >$dir/sample.bash
      myfunc () { :;}
      source $dir/other.bash
END
    echo 'sample () { :;}' >$dir/other.bash
    result=$(_functions_ $dir/sample.bash)
    assert equal myfunc "$result"
  ti
{% endhighlight %}

If the file sources any other files, we *don't* want to alias those,
however. Let's make sure that doesn't happen.

{% highlight bash %}
_functions_ () {
  env -i bash <<END
    shopt -s expand_aliases   # new
    alias source=:            # new
    \\source $1               # changed
    compgen -A function
END
}
{% endhighlight %}

Masking *source* with an alias gives us a two-fer.  It stops *source*
from importing the sub-file, and it doesn't add a *source* replacement
function that we'd also need to worry about filtering.

We then have to call the real *source* with a leading backslash (escaped
with another since it's in a double-quoted string) in order to get the
original file to load.

{% highlight bash %}
it "returns 0 if there are no functions defined"
  echo : >$dir/sample.bash
  _functions_ $dir/sample.bash
  assert equal 0 $?
ti
{% endhighlight %}

*compgen* returns false if there are no functions defined, so we want to
make sure this doesn't cause our import to trigger *errexit*.

{% highlight bash %}
_functions_ () {
  env -i bash <<END
    shopt -s expand_aliases
    alias source=:
    \\source $1
    compgen -A function;:   # changed
END
}
{% endhighlight %}

Here we add *;:* so the bash command returns true independent of
*compgen*'s result (*errexit* isn't on inside the bash command since we
haven't turned it on).

{% highlight bash %}
it "silences any output from the file"
  cat <<'  END' >$dir/sample.bash
    echo hello
    echo hello >&2
  END
  result=$(_functions_ $dir/sample.bash)
  ! in? "$result" hello
  assert equal 0 $?
ti
{% endhighlight %}

Since *\_functions\_* returns its value via stdout, we need to ensure that
it isn't adulterated by any output from the sourced file.

{% highlight bash %}
_functions_ () {
  env -i bash <<END
    shopt -s expand_aliases
    alias source=:
    \\source $1 &>/dev/null   # changed
    compgen -A function;:
END
}
{% endhighlight %}

Here we just silence stdout and stderr from the *source* command.

All right, now we have a list of functions. Let's start namespacing our
imports. We're back to *describe module* here:

{% highlight bash %}
it "imports a function"
  echo 'foo () { :;}' >$dir/sample.bash
  result=$(env -i bash <<END
    source module $dir/sample.bash
    compgen -A function
END
  )
  assert equal $'_functions_\nsample.foo' "$result"
ti
{% endhighlight %}

We're clearing the environment, then using our module to source the
sample file via *source module*, which takes *$dir/sample.bash* as an
argument.

In addition to the namespaced function, we'll have the *_functions_*
function as well, which is fine.

{% highlight bash %}
#!/usr/bin/env bash

declare -A _modules_
[[ -v _modules_[$1] ]] && return

_functions_ () {
  env -i bash <<END
    shopt -s expand_aliases
    alias source=:
    \\source $1 &>/dev/null
    compgen -A function;:
END
}

[[ -z $1 ]] && return     # new

_module_=${1##*/}         # new
_module_=${_module_%.*}   # new

shopt -s expand_aliases                     # new
for _function_ in $(_functions_ $1); do     # new
  alias $_function_=$_module_.$_function_   # new
done                                        # new

source $1
_modules_[$1]=''
{% endhighlight %}

Here we generate aliases for all of the functions in the requested
source file. Although we store the full pathname of the file as the
module key in our hash, the qualifier has to be just the filename
without any extension. That's what the loop creates with its aliases.

{% highlight bash %}
it "allows functions to call other functions"
  cat >$dir/sample.bash <<'  END'
    foo () { bar        ;}
    bar () { echo hello ;}
  END
  source module $dir/sample.bash
  result=$(sample.foo)
  assert equal hello $result
ti
{% endhighlight %}

Here we're just making sure that calls to other functions within the
module work from within the module. This already passes with the
existing alias code.

Since the functions are rewritten as they are defined, all of the
aliases we generated are not only useless afterward, they are now
unwanted since they'll interfere with our regular functions.

{% highlight bash %}
it "doesn't leave aliases"
  echo 'foo () { :;}' >$dir/sample.bash
  source module $dir/sample.bash
  ! alias foo &>/dev/null
  assert equal 0 $?
ti
{% endhighlight %}

Let's make sure they're cleaned up.

{% highlight bash %}
_module_=${1##*/}
_module_=${_module_%.*}

shopt -s expand_aliases
_functions_=$(_functions_ $1)           # new

for _function_ in $_functions_; do      # changed
  alias $_function_=$_module_.$_function_
done

source $1
_modules_[$1]=''

for _function_ in $_functions_; do      # new
  unalias $_function_                   # new
done                                    # new
{% endhighlight %}

This is pretty self-expanatory.

This is pretty much everything, with one exception...we want the module
we are loading to also be able to load its own modules. Since we're
relying on aliases to do the namespacing, when such a second module load
happens, its aliases get merged with the existing ones for the initial
load.

That's fine as long as there's no overlap in function names, but that's
precisely what we're trying to achieve with our namespacing...we want
files to be able to use the same names without conflict. If there's a
conflict in function names, the second module's alias will wipe out the
first one's, probably before the first one finishes loading its
functions.

Here's a test:

{% highlight bash %}
it "allows modules to import other modules"
  cat >$dir/foo.bash <<END
    source module $dir/bar.bash
    bat () { :;}
END
  cat >$dir/bar.bash <<END
    source module $dir/baz.bash
    bat () { :;}
END
  echo 'bat () { :;}' >baz.bash
  result=$(env -i bash <<END
    source module $dir/foo.bash
    compgen -A function
END
  )
  assert equal $'_functions_\nbar.bat\nbaz.bat\nfoo.bat' "$result"
ti
{% endhighlight %}

This is a bit more complex, so let's break it down.

There are three modules, *foo.bash*, *bar.bash* and *baz.bash*. They all
define the same function name, *bat*.

*foo* sources *bar* as a module. *bar* in turn sources *baz* as a
module.

The desired outcome is that we get three functions as a result,
*foo.bat*, *bar.bat* and *baz.bat*.

{% highlight bash %}
_module_=${1##*/}
_module_=${_module_%.*}

_aliases_+=( "$(alias)" )     # new
unalias -a                    # new

shopt -s expand_aliases
_functions_=$(_functions_ $1)

for _function_ in $_functions_; do
  alias $_function_=$_module_.$_function_
done

source $1
_modules_[$1]=''

for _function_ in $_functions_; do
  unalias $_function_
done

eval "${_aliases_[-1]}"         # new
unset -v _aliases_[-1]          # new
{% endhighlight %}

The solution here is to take whatever existing aliases there are when
we're about to import a module, stick them on a stack and pop the stack
when we're done.

In bash, an array can easily be purposed as a stack.  We're introducing
*\_aliases\_* here as an array for this purpose.

Fortunately, there's also an easy way to store the defined aliases. The
*alias* command by itself puts on stdout an eval'able list of all of the
commands which constitute the current aliases.  They can be stored as a
single string on top of the *\_aliases\_* stack with the *+=* operator.

Clearing the current aliases is simple too, just *unalias -a*.

When we're done, we pop the stack by eval'ing the last element with a -1
index, and then unsetting the same index.

As I laid out at the beginning of the post, there's plenty of other
module functionality which I haven't been able to address, but singular
importation and namespacing of functions are two of the most important,
and there are remarkably simple ways to accomplish them. I'll call that
victory. Modules!

Continue with [part 34] - indirection

  [part 1]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
  [Last time]: {% post_url 2018-10-11-approach-bash-like-a-developer-part-32-parallelism %}
  [-v test]: http://wiki.bash-hackers.org/commands/classictest#misc_syntax
  [the documentation]: https://www.gnu.org/software/bash/manual/html_node/Aliases.html
  [part 34]: {% post_url 2018-10-28-approach-bash-like-a-developer-part-34-indirection %}
