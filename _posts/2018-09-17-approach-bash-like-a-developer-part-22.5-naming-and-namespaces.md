---
layout: post
title:  "Approach Bash Like a Developer - Part 22.5 - Naming and Namespaces"
date:   2018-09-17 01:00:00 +0000
categories: bash
---

This is part 22.5 of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we discussed data types.  This time, let's discuss
naming and [namespaces].

Would Smell as Sweet
--------------------

My bash scripts primarily deal with three namespaces:

-   variable names

-   function names

-   alias names

While it's possible to export functions in bash, the function namespace
is not inherited by default.  Therefore all you have to worry about with
function names is your own names and anything you source.

Aliases are their own namespace, although of course they will mask
functions of the same name.  Still, if you unset an alias, it will not
affect the function and the function will be available once more.
Aliases can't be exported and are never inherited.

We'll be mostly focusing on variable names for the rest of this post.

An Aside on Unsetting Variables and Functions
---------------------------------------------

Before we do though, there is actually one place that the variable and
function namespaces do overlap, and that's when you're unsetting a name.

The *unset* command is used to unset both variables and functions.  If
you unset a function and a variable with the same name, it will unset
the variable first.  If you do it again, only then will it unset the
function.

This makes it easy unset a variable when you meant to unset a function,
or to unset a function because you forgot you already unset the variable
name.

For that reason, you should always use an option to *unset* which
applies for what you're trying to do.  If you're unsetting a variable,
use *unset -v*.  If you're unsetting a function, use *unset -f*.

Variable Namespaces
-------------------

I'm primarily concerned with the variable namespace, which includes the
environment.

I'll start by highlighting the fact that most environment variables use
all-caps for their names.  We should follow the same convention with any
variables we export in our programs.

But why are environment variables named in all caps?  The basic idea is
to reduce clutter and therefore the potential for conflict.
Interestingly, that happens to be a basic idea of all namespaces.

Shells are a special programming environment because they share some of
their namespace (the environment) with other instances of themselves.
In most programming environments, you start with a clean variable
namespace...perhaps there are a few special builtin variables, but for
the most part, the space is yours.

With bash, however, it starts with any defined environment variables.
Any user can define whatever variables they want.  Many packages
intended for interactive use at the command line create environment
variables that no other program cares about, but every program still
receives.  The more environment variables that are defined, the more
that are inherited, and it can turn into a big heap of random names.

If you were to reuse one of those names in your program, you would
inadvertently export your value for the variable.  That's because when
you modify an existing environment variable, it remains exported.  Your
code wouldn't even know.

So, getting back to the answer to our question, environment variables
use all caps because that is a poor-man's version of namespacing.  If
all environment variables use all-caps, and all regular shell variables
*don't* use all-caps, then they will never conflict.

That's what namespacing is about, making sure that variable names don't
accidentally overlap.  By making sure of that, we eliminate an entire
class of possible programming mistake.

Namespaces on the Cheap
-----------------------

Really, all it takes to make a poor man's namespace is a convention.
Using all-caps for names is one such convention.  The thing is, the
convention has to be must be unique enough that no one will use it
accidentally.

For example, if you had a library module you were writing, a short name
or id for it could serve as a prefix for your variable names.
A module named "mymodule" could have a "mym_" prefix for its global
variables.  That's sufficient for a cheap namespace.

Of course, you only need to worry about global variables if you're
developing code for use as third-party code.  It's a good practice for
environment variables in all cases, however.  Unique prefixes make for
good cheap namespaces.

By the same token, postfixes work just as well as a convention for cheap
namespacing.

Bash Variable Identifiers
-------------------------

Acceptable variable names in bash are fairly proscribed.  Variable
identifiers consist of alphanumeric characters, uppercase or lowercase,
and the underscore character.  The first character of the id cannot be a
number, however, leaving underscore and alphabetical characters.

By convention, most programmers use [snake_case] for bash variable names
since it's easy (no pressing shift) and underscore is a valid character
for identifiers.  It's also very readable and doesn't conflict with
environment variable names.

You can make this work for yourself as well.  Any time you break that
convention, you're necessarily creating a new namespace.

Convenient Conventions
----------------------

Here are the conventions I follow in general for scripts.

If I'm writing a module for use in other scripts, I create a prefix
that all globals and environment variables can use, as mentioned.  The
following are for when I don't have to worry about that, but want to
ensure that variables within my program don't conflict.

### Constants

For some time, I tried making all global names separate from local
variable names, but sometimes it doesn't make sense.  It's occasionally
useful to override a global variable with a local one.  Dynamic scoping
makes it possible to mask globals with locals.  In that case, they need
to be in the same namespace.

Constants, however, are a special kind of global.  Constants don't
change.   They should never need to be overridden by a local, so they
can have their own namespace.  We can avoid overlap with this type of
global at the least.

My method is to stick with snake_case, but to capitalize the first
letter of the constant, for example: *My_constant*.

### Locals with References

We'll discuss [indirection] later, but it's the other case where I use a
convention to namespace my variables.  The reason being that if you pass
a variable name to a function and want to set (or read) that variable in
the function, you can't use local variables of the same name within that
function.

Because you can't know what that variable name will be, you have to
namespace your local variables.  I use a trailing underscore, such as
*my_local_* because a single underscore is minimally obtrusive and still
very readable, which is important when all of your variables are using
it.

Continue with [part 23] - passing arguments

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-09-02-approach-bash-like-a-developer-part-22-data-types                %}
  [namespaces]:   https://en.wikipedia.org/wiki/Namespace
  [snake_case]:   https://en.wikipedia.org/wiki/Snake_case
  [indirection]:  https://en.wikipedia.org/wiki/Indirection
  [part 23]:      {% post_url 2018-09-13-approach-bash-like-a-developer-part-23-passing-arguments         %}
