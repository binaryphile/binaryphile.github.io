---
layout: post
title:  "Approach Bash Like a Developer - Part 31 - getopt"
date:   2018-10-08 01:00:00 +0000
categories: bash
---

This is part 31 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed option parsing. This time, let's talk about
adding *[getopt]*'s functionality to our parser.

You can read *getopt*'s man page for full details on its usage.  The
gist of it is that getopt is a tool which takes your option definitions,
much like our existing parser, and ingests the argument list.

Its output is the same argument list, except the arguments have been
reformatted into the form that our existing parser understands.  All of
the variants for short and long named arguments (space, no space, equals
sign, no equals sign) are standardized to a single space. Any invalid
options generate an error message and return code.

If you read many blogs or stackoverflow questions on *getopt*, you'll
see many recommendations to use *getopts* instead (note the "s" at the
end). From the [Wikipedia page] for *getopts*, you can see the
comparison between versions, as well as the source of some confusion due
to the history of the two.

What it all boils down to is that gnu *getopt*, not *getopts*, is the
best implementation of the three versions. It happens to share its name
with the original *getopt*, which is the worst of the three, hence some
confusion.

You'll see the current version of *getopt* called *enhanced getopt*
sometimes, and that is the one included in linux by default in the
util-linux package.

*getopt* is an external program, not a shell builtin like *getopts*, so
occasionally folks will make the argument that it's more universal, and
perhaps so since MacOS doesn't have the gnu version, but *getopt* is
significantly better than *getopts*.  Again, use homebrew to make MacOS
useful.

In any case, the point of the *getopt* utility is to handle some of the
messier details of the various formats allowed by the specifications.
For example, the spec allows the use of any unique prefix of a long
option, which means that a long option may be represented by a number of
actual strings.  Implementing your own logic to determine the smallest
unique prefix, and to match any longer version, would be a lot of work
for a simple command-line script.

The way to test which version of *getopt* you have on your system is to
run:

{% highlight bash %}
getopt -T
{% endhighlight %}

If the result code is 4, you have the enhanced version.

We could go about using *getopt* in two different ways.  We could use it
directly and pass its output to our *parseopts*.  This would require us
to define our options for *getopt* using its format, then to redefine
them for our own parser.  Obviously this sounds like more work, but it
does give us the ability to denote the difference between required
arguments and optional arguments (usually these are named arguments,
since required flags don't make much sense).

The other option is to enhance the *parseopts* function to take our
definition of the options, redefine them itself using *getopt*'s format
so it can call *getopt*, then do so, all behind the scenes.

I won't go through the tdd'ing of option 2 at this point, but will
instead go straight to the punchline:

{% highlight bash %}
denormopts () {
  local -n _names_=$2
  local -n _flags_=$3
  local -n _getopts_=$4
  local IFS=$IFS
  local _defn_
  local _long_=''
  local _oldIFS_=$IFS
  local _opt_
  local _short_=''

  _getopts_=([long]='' [short]='')
  for _defn_ in $1; do
    IFS=,
    set -- $_defn_
    IFS='|'
    for _opt_ in $1; do
      _names_[$_opt_]=$2
      case $_opt_ in
        -?  ) _short_+=,${_opt_#?};;
        *   ) _long_+=,${_opt_#??};;
      esac
      case ${3:-} in
        '' )
          case $_opt_ in
            -?  ) _short_+=: ;;
            *   ) _long_+=:  ;;
          esac
          ;;
        * ) _flags_[$_opt_]=1;;
      esac
    done
  done
  IFS=$_oldIFS_
  present? $_long_  && _getopts_[long]=${_long_#?}
  present? $_short_ && _getopts_[short]=${_short_#?};:
}

parseopts () {
  local defs_=$2
  local -n opts_=$3
  local -n posargs_=$4
  local -A flags_=()
  local -A getopts_=()
  local -A names_=()
  local rc_
  local result_

  _err_=0
  set -- $1
  denormopts "$defs_" names_ flags_ getopts_

  [[ -n $(type -p getopt) ]] && {
    getopt -T && rc_=$? || rc_=$?
    (( rc_ == 4 )) && {
      ! result_=$(getopt -o "${getopts_[short]}" ${getopts_[long]:+-l} ${getopts_[long]} -n $0 -- $@)
      (( $? )) || {
        _err_=1
        return
      }
      eval "set -- $result_"
    }
  }
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
        opts_+=( ${names_[$1]}=$2 )
        shift
        ;;
      * ) opts_+=( ${names_[$1]}=1 );;
    esac
    shift
  done
  posargs_=( $@ )
}
{% endhighlight %}

{% highlight bash %}
it "accepts a short option with no space"
  defs=( -o,o_val )
  args=( -oone    )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal o_val=one "$options"
ti

it "accepts a long option with an equals sign"
  defs=( --option,option_val  )
  args=( --option=sample      )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal option_val=sample "$options"
ti

it "accepts a prefix of a long option"
  defs=( --option,option_val  )
  args=( --opt=sample      )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal option_val=sample "$options"
ti

it "accepts multiple short flags"
  defs=(
    -o,o_flag,f
    -p,p_flag,f
  )
  args=( -op )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  expecteds=(
    o_flag=1
    p_flag=1
  )
  assert equal "${expecteds[*]}" "${options[*]}"
ti

it "accepts multiple short flags with a trailing short named argument"
  defs=(
    -o,o_flag,f
    -p,p_flag,f
    -q,q_val
  )
  args=( -opq one )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  expecteds=(
    o_flag=1
    p_flag=1
    q_val=one
  )
  assert equal "${expecteds[*]}" "${options[*]}"
ti

it "accepts a flag after positional arguments"
  defs=( -o,o_flag,f  )
  args=( one -o       )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal o_flag=1 "$options"
ti

it "a positional argument before a flag"
  defs=( -o,o_flag,f  )
  args=( one -o       )
  parseopts "${args[*]}" "${defs[*]}" options posargs
  assert equal one "$posargs"
ti
{% endhighlight %}

  [part 1]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
  [Last time]: {% post_url 2018-09-28-approach-bash-like-a-developer-part-30-option-parsing %}
  [getopt]: http://frodo.looijaard.name/project/getopt/man/getopt
  [Wikipedia page]: https://en.wikipedia.org/wiki/Getopts
