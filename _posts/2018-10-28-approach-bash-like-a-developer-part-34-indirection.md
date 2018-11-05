---
layout: post
title:  "Approach Bash Like a Developer - Part 34 - Indirection"
date:   2018-10-28 01:00:00 +0000
categories: bash
---

This is part 34 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we implemented a basic module system. This time, let's talk
about variable [references and indirection].

A reference in bash is simply the contents of a variable being the name
of another variable.  This is occasionally useful when you don't know
the name of a variable at the time you are writing a script, but you
want to manipulate its value anyway.

This can be the case when you are writing a library with functions
intended for use in other scripts.  For example, the caller may want you
to return a value in a variable of their choosing.  They can pass in the
name as an argument to your function.

The name of the variable is called the reference to it.  Using the name
to manipulate the variable is called dereferencing.  The technique in
general is called indirection, since you are accessing the variable
indirectly, first accessing the name then the variable.

Eval Indirection
----------------

Due to the fact that there is an *eval* command in bash, it has always
supported indirection in some fashion.  For example, if I have a
variable named *bar* and a variable named *foo* whose value is bar, I
can read it's value this way:

{% highlight bash %}
bar="my value"
foo=bar
eval "echo \"bar's value is \$$foo\""
{% endhighlight %}

The escaped dollar-sign allows the value of *foo* to be expanded first
(to *bar* in this case), and then evaluated as a normal variable
expansion by *eval*.

A value could be written to *foo*'s reference this way:

{% highlight bash %}
eval "$foo='my value'"
{% endhighlight %}

The nice thing about *eval* is that it's always been able to work with
array and hash variables as easily as normal values (as opposed to the
upcoming methods).  The variable with the reference can contain an index
as well (e.g. *foo=bar[2]*), or you can tag one on in the string you
*eval*:

{% highlight bash %}
myarray=( zero one two )

# without index
ref_=myarray
eval "echo \"first element is: \${$ref_[0]}\""

# with index
ref_=myarray[0]
eval "echo \"first element is: \${$ref_}\""
{% endhighlight %}

Read and Printf Indirection - Setting Values
--------------------------------------------

Another way to set values indirectly is to use *read* since it takes a
variable name as an argument:

{% highlight bash %}
foo=bar
read -r $foo <<END
my value
END
echo $bar   # echos 'my value'
{% endhighlight %}

I'm not sure if it has always been true, but you can assign to array and
hash elements this way with recent versions of bash.

{% highlight bash %}
myarray=( zero one two )
foo=myarray[1]
read -r $foo <<END
my value
END
echo ${myarray[1]}  # echos 'my value'
{% endhighlight %}

At some point, bash also added the ability to set variables with
*printf* as well:

{% highlight bash %}
printf -v $foo %s "my value"
{% endhighlight %}

It did not initially support array or hash item references, but recent
versions of bash do support it.  It works the same as the prior *read*
example.

Bash Indirect Expansion - Getting Values
----------------------------------------

The last two methods set values, but there is also a method for getting
values which was added to bash later, called [indirect expansion].

Indirect expansion takes the form *${!myvar}*.  Unfortunately, it shares
the same *!* operator as the index expansion for arrays and hashes which
takes the form *${!myarray[\*]}*.  You can see why it's easy to confuse.

Indirect expansion only works when the referenced variable name is a
scalar variable, or when the reference includes a name as well as an
index.  You can't use indirect expansion to tag an array index on the
outside of the variable reference.  For example, this doesn't work:

{% highlight bash %}
myarray=( zero one two )
ref_=myarray
echo ${!ref_[1]}  # doesn't work
{% endhighlight %}

To get to the array element, you have to include the index in the
reference:

{% highlight bash %}
myarray=( zero one two )
ref_=myarray[1]
echo ${!ref_}     # does work
{% endhighlight %}

The former example which doesn't work is doing something else...it's
trying to find a variable reference contained in an array element.  For
example, this does work:

{% highlight bash %}
myrefs_=( varzero varone )
varone='my value'
echo ${!myrefs_[1]}   # echos 'my value'
{% endhighlight %}

This works because it looks at the array item at index 1 first, then
dereferences it with the *!* operator.

One neat thing about indirect expansion is that it can reference
positional arguments as well.  For example, if *ref_* holds the value
"1", then *${!ref_}* expands to the value of the positional argument
*$1*.  We've also already seen the very meta *${!#}* expansion, which
refers to the last positional argument (since $# is the index of the
last argument). You can't do either of those with a nameref, described
next.

Nameref Indirection
-------------------

Finally, in bash 4.3, it began supporting namerefs.  Namerefs are
created with *declare -n* and *local -n*.  You can only supply a
variable name as a value during the declaration.  Thereafter, any
manipulation of the nameref is applied instead to the referenced
variable.

{% highlight bash %}
declare -n ref_=varname
ref_=myvalue    # sets "varname" to "myvalue"
{% endhighlight %}

Namerefs are by far the easiest to work with, since once they are
created, you simply use them as if you would a normal variable.  They
work equally well for scalars, arrays and hashes as well.

However, since they don't work with all versions of bash, you may still
need to use the other methods for backwards compatibility.

A Special Use Case for Printf
-----------------------------

There is a case where *printf* can be useful for a particular situation.
When you write a function where you want to supply a reference to a
return variable in some cases, but get your value on stdout in others
(such as in a pipeline), *printf* can be used for both:

{% highlight bash %}
describe myfunc
  it "outputs the value in the named variable"
    myfunc result
    assert equal "my value" $result
  ti
end_describe
{% endhighlight %}

Here's the indirect version.

{% highlight bash %}
myfunc () {
  local ref_=${1:-}

  printf $ref_ %s "my value"
}
{% endhighlight %}

Here's the stdout version.

{% highlight bash %}
it "outputs the value on stdout"
  result=$(myfunc)
  assert equal "my value" $result
ti
{% endhighlight %}

It only differs by the fact that no reference is provided as an
argument.

{% highlight bash %}
myfunc () {
  local ref_=${1:-}

  printf ${ref_:+-v$IFS$ref_} %s "my value"
}
{% endhighlight %}

The *${ref\_:+-v$IFS$ref\_}* expression checks to see if *ref\_* is set.
If not, it doesn't evaluate to anything.

Since it's not double-quoted, if it expands to an empty value, bash
removes it as an argument to *printf*.

If *ref_* is set, the expression evaluates to the *-v* option.

Since the expression isn't double-quoted, when it expands to *-v*, it
then splits (by definition) on the embedded *IFS*.  Finally, the name in
*ref_* is expanded to give the argument to *-v*.

In this model, the return method is determined by whether the reference
argument is supplied.  That necessarily makes the argument an optional
one.

Usually there are more arguments to real functions.  That means that the
reference argument needs to come at the end of that list, if it's an
optional positional argument.

If there are more than one optional arguments to a function, I stop
using positionals for the optional arguments and instead use keyword
arguments.  A reference argument in that case becomes something like
*ref_=varname* instead of just *varname*.

A Word on Namespaces
--------------------

The easiest thing to mess up with a reference in any of these methods is
to accidentally set the reference to itself, or another variable you
didn't intend, such as a local variable which happens to have the same
name.

References don't provide any protection against such naming conflicts.
If you use a reference to return a value from a function, I highly
suggest you namespace all of your locals with a trailing underscore as
I've done in my examples.  Anything else can be more of an eyesore, and
anything less can result in a bug or program stop:

{% highlight bash %}
> declare -n myvar=myvar
bash: declare: myvar: nameref variable self references not allowed
{% endhighlight %}

The nameref method causes an immediate error.

{% highlight bash %}
myfunc () {
  local myvar=$1
  # oops, we passed it "myvar" as $1, referring to an outer myvar

  printf -v $myvar %s "my value"
  # "my value" just got assigned to our local variable, not the outer one
  # it goes away when the function ends because it's local
}
{% endhighlight %}

The *printf* method simply malfunctions silently.

Of course, if you're in a function which is namespaced with trailing
underscores, you can still get conflicts if you feed a reference to
*another* function which also namespaces with trailing underscores, so
you have to be conscious of such multi-level naming concerns when
dealing with references.

Occasionally you'll see my examples namespace variables with leading and
trailing underscores to allow a reference to be passed from a caller
which uses trailing underscores, but I try not to go too far down that
rabbit hole.

Of course, one thing you can do to avoid namespacing and name collisions
is to not use variables at all, other than positional arguments.  If you
are lucky, you can either simply refer to the positional arguments as is
or reset them as needed with the *`set --`* command.  This method is
preferable if you can pull it off, but it's not often that you can.

  [part 1]: {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro %}
  [Last time]: {% post_url 2018-10-16-approach-bash-like-a-developer-part-33-modules %}
  [references and indirection]: https://en.wikipedia.org/wiki/Reference_(computer_science)
  [indirect expansion]: http://wiki.bash-hackers.org/syntax/pe#indirection
