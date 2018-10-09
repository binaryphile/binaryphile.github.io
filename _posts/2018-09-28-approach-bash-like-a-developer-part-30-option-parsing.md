---
layout: post
title:  "Approach Bash Like a Developer - Part 30 - Option Parsing"
date:   2018-09-28 01:00:00 +0000
categories: bash
---

This is part 30 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed debugging. This time, let's talk about parsing
options to command-line scripts.

You wouldn't necessarily think so, but parsing options can actually be a
bit of a challenge. Mostly that's due to the fact that over time, more
and more flexibility has been added to the way standard utilities deal
with options. These features have now become *de rigeur*.

There are somewhat formal descriptions of how options should be able to
be specified to unix utilities. I'll reference them later, but let's
start with a simplified picture.

After the name of the command itself, the command-line takes two kinds
of input.

The first kind are options. Options are designated with a hyphen,
followed by the option name itself. A short option has a single hyphen
and a single character, such as *-h* for help. A long option has a
double-dash and multiple characters, such as *`--help`*.

The second kind are positional arguments, which typically follow the
options. A positional argument is a value by itself with no other
adornment to give it meaning besides its position in the list of
arguments. They might represent a filename or something else with a
string value.

In the realm of options there are also two kinds of values which they
represent.

Flags are options which represent boolean values. The presence of the
option in the command typically represents true, while the absence of
the option represents false.

They are bare options with no other associated information in the
command, and usually indicate that the command should change its
behavior or do something special, such as print out the help message and
exit.

Named arguments are options which form a key-value pair, the name of the
option being the key, and the value following the option on the
command-line, e.g. *`--option value`*.

Named arguments can make string-valued arguments optional, since they
may or may not be provided and do not affect the ordering of positional
arguments by their absence.

A single hyphen by itself is a valid positional argument or value to a
named argument and is not a flag.

Finally there is a special option of a bare double-dash, *`--`*. It
signifies the end of the options and beginning of positional arguments.
After this option, arguments may have values which start with one or two
hyphens, whereas before the double-dash those would be interpreted as
options instead of values.

All of these rules have been extended or broken with modern
command-lines, but we'll start with them. They are hard enough already!
Even the long options aren't part of the [posix specifications], but
they are too ubiquitous and useful to skip.

If you search around for how to parse options in bash natively, without
the help of external utilities such as [getopt], it usually boils down
to something like this in the main body of the script:

{% highlight bash %}
while [[ $1 == -?* ]]; do
  case $1 in
    -- )
      shift
      break
      ;;
    -o|--option1 )  # flag
      o_flag=1
      ;;
    -p|--option2 )  # named argument
      shift
      option2_var=$1
      ;;
    * )
      echo "Invalid option: $1"
      echo "$usage"
      exit 2
      ;;
  esac
  shift
done
{% endhighlight %}

This sets some variables based on the options, leaving the positional
arguments intact. It handles short and long options, both flags and
named arguments. It stops when it encounters a double-dash. Anything
else which looks like an option consisting of a hyphen and at least
another character is flagged as an unrecognized option.

The *shift* at the end of the loop ensures that it ends when the
arguments do.

We're going to use the same basic template, but make it more general by
parameterizing the definition of the acceptable options. The *parseopts*
function will allow the caller to specify which options are allowed, and
will return the positional arguments as well as the options it found on
the command-line. It will accept the raw command-line as an argument as
well.

Since we've got different types of options, we'll need to pass in a data
structure. It only needs a few elements. I'll use an array with an item
for each option definition. Each definition will include two parts,
separated by commas.

The first part will be the acceptable option forms, including short and
long name if desired, e.g. *`-o|--option`*. *|* is used to separate the
forms only if both are given.

The second part is the name we'd like it to be stored in. We won't be
creating variables with them just yet, but the return value should
include an array of the options where the elements are in the form of
*key=value*, *key* being the name provided here.

Finally, we'll need something to tell the difference between flags and
named arguments in our definition. I'll keep it simple and just say that
flags get a third element which is always "f", for flag. Named arguments
won't require a third element.

{% highlight bash %}
defs=(
  -o|--option1,o_flag,f
  -p|--option2,option2_var
)
{% endhighlight %}

In addition to the parsed options, when the function returns we'll also
want the remaining positional arguments. When we call *parseopts*, not
only will we provide the raw arguments and our options definitions,
we'll also provide the name of two variables we'd like the return arrays
to be stored in, one for the options and the other for the remaining
positional arguments.

First test:

{% highlight bash %}
describe parseopts
  it "returns a short flag"
    defs=( -o,o_flag,f  )
    args=( -o           )
    parseopts "${args[*]}" "${defs[*]}" options posargs
    assert equal o_flag=1 $options
  ti
end_describe
{% endhighlight %}

Here's the first code:

{% highlight bash %}
parseopts () {
  local defs_=$2
  local -n opts_=$3
  local flags_
  local names_

  set -- $1
  denormopts "$defs_" names_ flags_
  local -A names_=$names_
  opts_=${names_[$1]}=1
}
{% endhighlight %}

The function creates a hash called *names\_*, which is indexed by the
option, in this case *-o*. The hash entry contains the name of the
variable in which we'll store the option's value. The name in this test
is *o\_flag*. We've made a function *denormopts* to handle creating that
hash, which I'll show later.  In anticipation of some future tests,
we'll also hand it a *flags\_* return variable, but we won't use it just
yet.

We're also using the *-n* option with the *local -n opts\_* declaration.
This is a feature of more recent bash versions. It allows the use of
indirection. When the variable is declared, it's initialized with the
name of another variable (the name of the caller's *options* return
variable in this case). From then on, working with the *opts\_* variable
actually manipulates the variable named by it.

Note that this kind of indirection doesn't absolve us of namespacing the
local variables away from the caller with the use a trailing underscore.
There can still be variable naming conflicts with the caller otherwise.

This code is just enough to make the test pass, so it's not able to
handle anything but this test. That's exactly as intended since we're
tdd'ing this. It's ok that we've hardwired the result to be a boolean
flag value, setting it's value to 1. We're also only dealing with a
single option instead of a list of them, and that's ok too.

{% highlight bash %}
it "returns with _err_=1 if the argument isn't defined"
  defs=( -o,o_flag,f  )
  args=( --other      )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal 1 $_err_
ti
{% endhighlight %}

Here we're testing that the function returns an error if the argument
looks like an option, but wasn't defined as one.

The key here is that we have to be talking about an argument which looks
like an option, i.e.  starts with a dash. An argument which doesn't look
like an option simply stops the option parsing and does not cause an
error.

{% highlight bash %}
parseopts () {
  local defs_=$2
  local -n opts_=$3
  local -n posargs_=$4
  local flags_
  local names_

  _err_=0                             # new
  set -- $1
  denormopts "$defs_" names_ flags_
  local -A names_=$names_
  defined? names_[$1] || {            # new
    _err_=1                           # new
    return                            # new
  }
  opts_=${names_[$1]}=1
}
{% endhighlight %}

This time we just test that the option is in the hash.  If not, it sets
*_err_* and returns.

I've created a *defined?* function which just wraps bash's [-v test],
which tests for the existence of a variable by its name (with index).
That's one way to test for the existence of a key in the *names\_* hash.

Because we're using the global *_err_* to indicate a problem, we need to
explicitly set it to 0 at the beginning of the function so we don't get
a stale value of *_err_* by accident, in the case that we don't need to
set it to 1.

{% highlight bash %}
it "returns a named argument"
  defs=( --option,option_val  )
  args=( --option sample      )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal option_val=sample $options
ti
{% endhighlight %}

Now for a named argument:

{% highlight bash %}
parseopts () {
  local defs_=$2
  local -n opts_=$3
  local -n posargs_=$4
  local names_
  local flags_

  _err_=0
  set -- $1
  denormopts "$defs_" names_ flags_
  local -A names_=$names_
  local -A flags_=$flags_             # new
  defined? names_[$1] || {
    _err_=1
    return
  }
  ! defined? flags_[$1]               # new
  case $? in                          # new
    0 ) opts_=${names_[$1]}=$2 ;;     # new
    * ) opts_=${names_[$1]}=1  ;;
  esac
}
{% endhighlight %}

*denormopts* has been updated to generate a hash whose keys are the flag
options.

The two *defined?* tests check to see if those keys exist. It serves as
a way to tell the difference between a named argument and a flag option.

{% highlight bash %}
it "returns a named argument and a flag"
  defs=(
    --option,option_val
    -p,p_flag,f
  )
  args=( --option sample -p )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  expecteds=(
    option_val=sample
    p_flag=1
  )
  assert equal "${expecteds[*]}" "$options"
ti
{% endhighlight %}

This tests that we can handle multiple arguments. In this case, the
*options* return value holds an array (as a string, concatenated with
*IFS*).

In order to make the comparison to the expected results easier, we
create an array of them and use the same concatenation style to compare.
These both require quotes in order to prevent word-splitting.

{% highlight bash %}
parseopts () {
  local defs_=$2
  local -n opts_=$3
  local -n posargs_=$4
  local flags_
  local names_
  local results_=()                       # new

  _err_=0
  set -- $1
  denormopts "$defs_" names_ flags_
  local -A names_=$names_
  local -A flags_=$flags_

  while (( $# )); do                      # new
    defined? names_[$1] || {
      _err_=1
      return
    }
    ! defined? flags_[$1]
    case $? in
      0 )
        results_+=( ${names_[$1]}=$2 )    # changed
        shift
        ;;
      * ) results_+=( ${names_[$1]}=1 );; # changed
    esac
    shift
  done
  opts_=${results_[*]}                    # new
}
{% endhighlight %}

Here we've added a loop to process multiple arguments. It uses the
shift-and-test-argument-length method outlined at the beginning of the
post. It gathers the resulting key=value pairs in an array and passes it
back via indirection through *ref\_*.

So far, so good.

Another test:

{% highlight bash %}
it "stops when it encounters a non-option"
  defs=( --option,option_val  )
  args=( --option sample -    )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal option_val=sample $options
ti
{% endhighlight %}

Let's stop parsing options when we encounter an argument which doesn't
start with a hyphen. To kill two birds with one stone, we'll use a
single hyphen as the non-option argument, since we recognize that as a
value, not an option.

{% highlight bash %}
parseopts () {
  local defs_=$2
  local -n opts_=$3
  local -n posargs_=$4
  local flags_
  local names_
  local results_=()

  _err_=0
  set -- $1
  denormopts "$defs_" names_ flags_
  local -A names_=$names_
  local -A flags_=$flags_

  while [[ ${1:-} == -?* ]]; do             #changed
    defined? names_[$1] || {
      _err_=1
      return
    }
    ! defined? flags_[$1]
    case $? in
      0 )
        results_+=( ${names_[$1]}=$2 )
        shift
        ;;
      * ) results_+=( ${names_[$1]}=1 );;
    esac
    shift
  done
  opts_=${results_[*]}
}
{% endhighlight %}

We've just changed the *while* loop to check and see that the current
argument looks like an option.  If not, we can stop there and return the
currently collected options.

{% highlight bash %}
it "stops when it encounters --"
  defs=(
    --option,option_val
    -p,p_flag,f
  )
  args=( --option sample -- -p )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal option_val=sample $options
ti
{% endhighlight %}

Let's make sure that double-dash signals the end of options.

{% highlight bash %}
parseopts () {
  local defs_=$2
  local -n opts_=$3
  local -n posargs_=$4
  local flags_
  local names_
  local results_=()

  _err_=0
  set -- $1
  denormopts "$defs_" names_ flags_
  local -A names_=$names_
  local -A flags_=$flags_

  while [[ ${1:-} == -?* ]]; do
    [[ $1 == -- ]] && {                   # new
      shift                               # new
      break                               # new
    }
    defined? names_[$1] || {
      _err_=1
      return
    }
    ! defined? flags_[$1]
    case $? in
      0 )
        results_+=( ${names_[$1]}=$2 )
        shift
        ;;
      * ) results_+=( ${names_[$1]}=1 );;
    esac
    shift
  done
  opts_=${results_[*]}
}
{% endhighlight %}

We've just added a check for double-dash at the top of the loop.  If we
find it, we shift the double-dash and break the loop, returning whatever
we've collected so far.

{% highlight bash %}
it "returns positional arguments"
  defs=( -o,o_flag,f  )
  args=( -o one two   )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  expecteds=( one two )
  assert equal "${expecteds[*]}" "$posargs"
ti
{% endhighlight %}

Finally, let's make sure that the positional arguments survive and are
handed back as well.

{% highlight bash %}
parseopts () {
  local defs_=$2
  local -n opts_=$3
  local -n posargs_=$4
  local flags_
  local names_
  local results_=()

  _err_=0
  set -- $1
  denormopts "$defs_" names_ flags_
  local -A names_=$names_
  local -A flags_=$flags_

  while [[ ${1:-} == -?* ]]; do
    [[ $1 == -- ]] && {
      shift
      break
    }
    defined? names_[$1] || {
      _err_=1
      return
    }
    ! defined? flags_[$1]
    case $? in
      0 )
        results_+=( ${names_[$1]}=$2 )
        shift
        ;;
      * ) results_+=( ${names_[$1]}=1 );;
    esac
    shift
  done
  opts_=${results_[*]}
  posargs_=$*             # new
}
{% endhighlight %}

We've added a few new lines to shift off the parsed value and return the
rest of the positionals.

There we go, a fully functional, programmable option parser.  We could
write a number more tests in order to make sure we cover a better
combination of inputs, but this covers the core of the functionality we
wanted.  If we encounter undesired behavior, we should write tests at
that point, both to fix the behavior as well as to ensure that the code
doesn't regress to that behavior in the future.

We could also add more features, such as automatic help message
generation or support for a a *version* option, but I'll leave that to
you.

The one thing we are missing is support for all of the variations of
syntax allowed by the posix and gnu specifications.  For example, short
named arguments are supposed to be usable either with or without a
whitespace between the option name and the value. These two are supposed
to be equivalent: *-o value* and *-ovalue*.  Long named arguments are
supposed to allow whitespace or an equals sign: *--option value* and
*--option=value*.

Obviously our code won't work for this, but rather than write tests and
rewrite the code to support it, gnu offers a tool called *getopt* which
helps handle these for you.  We'll discuss that in the next post.

But before that, I promised to show the code for the denormalization of
the option definitions.  I won't go through an explanation for it, but
you can probably figure it out by this point:

{% highlight bash %}
denormopts () {
  local -n _opts_=$2
  local -n _flgs_=$3
  local -A _flags_=()
  local -A _names_=()
  local IFS=$IFS
  local _defn_
  local _oldIFS_=$IFS
  local _opt_

  for _defn_ in $1; do
    IFS=,
    set -- $_defn_
    IFS='|'
    for _opt_ in $1; do
      _names_[$_opt_]=$2
      present? ${3:-} && _flags_[$_opt_]=1
    done
  done
  IFS=$_oldIFS_
  rep _names_ _opts_
  rep _flags_ _flgs_
}
{% endhighlight %}

Continue with [part 31] - getopt

  [part 1]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
  [Last time]: {% post_url 2018-09-27-approach-bash-like-a-developer-part-29-debugging %}
  [posix specifications]: http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html
  [getopt]: http://frodo.looijaard.name/project/getopt/man/getopt
  [-v test]: http://wiki.bash-hackers.org/commands/classictest#misc_syntax
  [returning errors]: {% post_url 2018-08-13-approach-bash-like-a-developer-part-15-strict-mode-caveats %}
  [part 31]: {% post_url 2018-10-08-approach-bash-like-a-developer-part-31-getopt %}
