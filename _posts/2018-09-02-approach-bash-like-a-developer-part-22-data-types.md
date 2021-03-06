---
layout: post
title:  "Approach Bash Like a Developer - Part 22 - Data Types"
date:   2018-09-02 01:00:00 +0000
categories: bash
---

This is part 22 of a series on how to approach bash programming in a way
that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed environment variables.  This time, let's
discuss data types.

Basic Types
-----------

Bash is like many dynamic languages in that it has a variety of data
types which include collection types, and does not require declaration
of types before assigning values to variables (with the exception of
hashes).

For basic types, bash supports two types:

-   strings - 'natch

-   integers - you know, for math

Strings can actually be used as integers as well, that is to say, they
work fine in arithmetic expressions so long as they hold the string
representations of integers.

Although it's fairly easy to use a string as an integer, declaring a
variable as an integer does get you something.  It allows you use an
arithmetic expression as a string on the right-hand side of an
assignment, without the need for an arithmetic expansion.

For example, you can use the assignment *local -i var='2 + 5'* to give
*var* the value of 7.  Once a variable has the integer attribute, you
can do the same without the *local* or *declare* attached.

The integer attribute also allows you to use the *+=* operator as a
mathematical addition, rather than appending a string.

It also happens to convert any non-integer string values you attempt to
assign to the variable into the value 0 (which can hardly be described
as a feature).  So be careful.

I use the integer declaration when it saves me some of the noisy
arithmetic expansion syntax.  Fewer *$(())*s are better.

Strings are the default, so they don't need any special option to
*[declare]* or *[local]*.

Collection Types
----------------

There are two collection types:

-   arrays - start-at-zero-indexed dynamic lists

-   associative arrays - a.k.a. hashes - key-value pairs of the basic
    types

Despite the fact that bash refers to both of these types as arrays, I
prefer to keep things clear by referring to one as arrays and the
other as hashes exclusively.

Arrays can skip indexes or have items deleted, which makes them sparse.

It is not possible to store collection types as items in another
collection.

Assignment to individual array items uses bracket notation, e.g.
*myarray[0]=zero*. The index can be an arithmetic expression following
the usual rules for such expressions (dollar-signs not needed for
variable references, etc.).

Hash keys are strings which can include spaces and do not require
quotes.  Like arrays, the values can be a mix of strings and integers.
Hashes do not interpret keys as arithmetic expressions.

Both arrays and hashes can be declared with the integer option, which
forces all elements to automatically be an integer.  You cannot mix
strings and integer types within an array nor hash.

Other Attributes
----------------

Variables can have other attributes assigned in their *declare* or
*local* statements:

-   read-only - *declare -r* or *[readonly]* - make the variable an
    unchangeable constant

-   global - *declare -g* - (*local* doesn't support *-g*) force the
    variable to the global scope

-   export - *declare -x* or *[export]* - export a variable to the
    environment

Assigning Values
----------------

Assigning values to the basic types is straightforward so I won't go
over it.  *declare* and *local* also allow you to assign values in the
same manner.  They also allow assignments to multiple variables in one
statement.  You can do the same with regular assignments as well.

There are two forms for assigning values to the collection types.

The first is assignment to an individual element in the collection,
which follows the same syntax as assigning to a regular variable, but
includes an index/key on the left-hand side:

{% highlight bash %}
myhash[key]=myvalue
myarray[index]=myvalue
{% endhighlight %}

For a hash, you must declare the variable with *declare -A* before
assigning values this way.

For arrays, assigning to the unsubscripted name is the same as assigning
to the zeroth element.  Expanding the unsubscripted name also expands
the zeroth element.

The second form is the assignment of a literal to the name of the hash
or array.  For arrays, it looks like:

{% highlight bash %}
myarray=( value1 value2 "value 3" )
{% endhighlight %}

Arrays can also have their indexes supplied if you want them to be
sparse:

{% highlight bash %}
myarray=( [0]=value1 [2]=value3 )
{% endhighlight %}

For hashes, it looks like:

{% highlight bash %}
declare -A myhash=( [one]=value1 [two]=value2 [three]="value 3" )
{% endhighlight %}

Unlike the other types, hashes must be declared as such before or during
assignment with the *declare -A* or *local -A* command.

Once declared, you can assign its value without redeclaring it though:

{% highlight bash %}
declare -A myhash
myhash=( [zero]=0 [one]=1 )
{% endhighlight %}

The *printf* command can also assign directly to array/hash elements
(as well as regular variables) with the *-v* option.

Arrays also support the *+=* operator, which appends to the end:

{% highlight bash %}
myarray+=( "new tail value" )
{% endhighlight %}

Unsetting an index of an array or hash removes that one element:

{% highlight bash %}
unset -v myarray[3]
{% endhighlight %}

For this reason, when looping through indexes of an array (or hash, for
that matter), you should use the [index expansion] rather than a counter
(reminder: *IFS* is set to blank):

{% highlight bash %}
for index in ${!myarray[@]}; do
  echo ${myarray[index]}
done
{% endhighlight %}

Namerefs
--------

Finally, namerefs are a special type of variable in recent versions of
bash.  There are a form of indirection:

{% highlight bash %}
declare -n myvar=variable_name
{% endhighlight %}

After the declaration, any reference to *myvar* will actually read or
write to the variable *variable_name* instead.

Automatic Conversion
--------------------

You can change a string variable to an array automatically if you use
the literal assignment syntax to assign an array value to an existing
string variable, or if you assign a value to a subscript of an existing
string variable.

Trying the same thing with a hash literal assignment, will turn the
variable into an array, not a hash.  There's no way to get around having
to use *declare -A* to get a hash.

Once a variable has been turned into an array type, it cannot be
converted to one of the basic types without unsetting it explicitly.

Since the conversion is irreversible, I try not to convert a string to
an array so I always know what kind of variable I'm dealing with.

Continue with [part 22.5] - naming and namespaces

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-02-approach-bash-like-a-developer-part-21-environment-variables     %}
  [declare]:      http://wiki.bash-hackers.org/commands/builtin/declare
  [local]:        http://wiki.bash-hackers.org/commands/builtin/local
  [readonly]:     http://wiki.bash-hackers.org/commands/builtin/readonly
  [export]:       http://wiki.bash-hackers.org/commands/builtin/export
  [index expansion]: http://wiki.bash-hackers.org/syntax/arrays#metadata
  [part 22.5]:    {% post_url 2018-09-17-approach-bash-like-a-developer-part-22.5-naming-and-namespaces       %}
