---
layout: post
title:  "Nix Language Primer"
date:   2018-07-22 00:14:31 +0000
categories: nix
---

Nix Language Primer
===================

Nix is a package manager much like apt, yum or homebrew.  Nix is also a
language by which the nix package manager specifies the packages
offered.

While nix (the language, not the package manager) is a complete
programming language, it is not general-purpose. Its primary focus is
declarative. It is used to create sets of parameters to be fed to
external compilation tools such as *configure* and *gcc*.

This is a primer for the nix language.  It is meant to enable you to
read nix expressions.  It does not attempt, for example, to teach you
about the nix build system, nor how to best compose package definitions.

Since any nix "program" is fundamentally a single nix expression, the
primary goal is to enable you to see where the sub-parts of an
expression begin and end.

For those coming from other languages, nix can be confusing due to its
use of semicolons and braces.  In this respect, nix is different than
many languages because it does not employ semicolons to separate
statements.  Instead, semicolons play a role more similar to commas in
other languages, separating elements within part of an expression.
Likewise, braces do not denote blocks, but rather sets and set patterns.

You will see more on this in the following sections.

Nix REPL
--------

{% highlight bash %}
nix-env -ibA nixpkgs.nix-repl
nix-repl
{% endhighlight %}

Playing with expressions in the nix command-line interpreter
(Read-Evaluate-Print-Loop) is encouraged.

Whitespace
----------

Whitespace generally does not matter in nix.

Comments
--------

{% highlight nix %}
# trailing comment

/* multiline comment */
{% endhighlight %}

Expressions
-----------

Nix is a pure functional language. There are no statements in nix, only
a top-level, single expression which in turn is composed of other
expressions. Every expression can be evaluated down to either a function
or a value.

Expressions are composed from values, functions (called lambdas) and
operations (operators with operands), as well as a handful of special
keyword expressions.

You can use parentheses around any expression for clarity or to force
precedence.

Boolean Values
--------------

{% highlight nix %}
true

false
{% endhighlight %}

Integers
--------

{% highlight nix %}
1

20
{% endhighlight %}

Strings
-------

{% highlight nix %}
"hello, world!"

"a multiline
string"

''a string containing the " symbol''
{% endhighlight %}

Interpolation ("Anti-quotation")
--------------------------------

{% highlight nix %}
"a string with a ${nix_expression}"
{% endhighlight %}

Files
-----

{% highlight nix %}
./filename.txt
{% endhighlight %}

Files are a basic type (they are not strings, so no quotes). They must
always contain a /.

Relative pathnames should always start with ./ to ensure the presence of
at least one /.

Relative paths are relative to the file in which they appear.

URLs
----

{% highlight nix %}
http://domain.com/path
{% endhighlight %}

URLs are a basic type. Again, no quotes.

Lists
-----

{% highlight nix %}
[ "one" "two" "three" ]
{% endhighlight %}

Lists are a container type for multiple values.

Lists can be empty:

{% highlight nix %}
[ ]
{% endhighlight %}

List elements can be of diverse types, including other lists or sets,
even within the same list.

Lists are not typically used as frequently as sets are.

Sets
----

Sets are the workhorse of nix.

Sets are a container type for multiple key/value pairs.  They are
analogous to hashes in other languages.

Nix refers to the keys as "attributes".

{% highlight nix %}
{ key1 = "value1"; key2 = "value2"; }
{% endhighlight %}

The final semicolon is required.

Accessing values in a set:

{% highlight nix %}
{ key = "value"; }.key
{% endhighlight %}

Sets can be empty:

{% highlight nix %}
{ }
{% endhighlight %}

Note that, in nix, braces are only used for sets and set patterns (see
below). There are no brace-delimited blocks as there are in other
languages.

For example, while the following may look like a function definition in
another language, a function name followed by braces is actually a
function invocation with an empty set as an argument, not a definition:

{% highlight nix %}
do_something { }
{% endhighlight %}

Function Definition and Patterns
--------------------------------

Functions are anonymous, meaning they don't have names in their
definitions. To give a name to a function, you bind it to a key or a
variable just as you would with any other value.

Functions start with an argument pattern:

{% highlight nix %}
# pattern: function body
  arg:     do_something_with arg  # do_something_with is a made-up function
{% endhighlight %}

"Argument pattern" is a fancy name for "give me a (single) variable name
for the argument".

There is only ever one argument to a function, however that one argument
may be a set, in which case you may use a set pattern in the
declaration:

{% highlight nix %}
# { set pattern                  }: function body
  { arg1, arg2 ? "default_value" }: do_something_with (arg1 && arg2)
{% endhighlight %}

Set patterns consist of the key names (with default values, if desired)
separated by commas, which become variables in the function scope.

Note that set patterns are the only construct in nix which uses commas,
and they don't need a final comma before the closing brace (unlike nix's
semicolon-based expressions).

Function Invocation
-------------------

Functions are invoked by passing an argument after a space. Parentheses
around the argument(s) are generally not required.

Note that you don't need to name the function, just pass an argument
after its declaration (parentheses for precedence):

{% highlight nix %}
# (function definition       ) <string argument>
  (arg: do_something_with arg) "value"
{% endhighlight %}

Functions specified with a set pattern must receive a set with exactly
the required keys and nothing more (minus any defaults, if desired):

{% highlight nix %}
# (function definition           ) <set argument>
  ({ arg }: do_something_with arg) { arg = "value"; }
{% endhighlight %}

Functions with "Multiple" Arguments
-----------------------------------

Functions can only take one argument, but they can return a function
which then takes the next argument:

{% highlight nix %}
arg1: arg2: do_something_with (arg1 && arg2)
{% endhighlight %}

Which syntactically breaks down to:

{% highlight nix %}
# (function 1    (function 2                            ))
  (arg1:         (arg2: do_something_with (arg1 && arg2)))
{% endhighlight %}

Calling the outer function with one argument returns the inner function,
curried with *arg1* (i.e. a function with a closure containing *arg1*).
That function may be later called just by providing *arg2*.

Scoping
-------

Nix is lexically scoped like most languages. Variables always resolve
the same way based on the local scope first, then up through parent
expression scopes, up to the global scope as necessary. The matching
name in the closest scope to the executing code is the value to which
the variable is resolved.

In the multi-argument function above, arg1 is available to the inner
function because arg1 is in the outer function's scope. Since it is the
parent expression, its scope is available to the child unless the child
masks that name with its own variable of the same name.

Variables
---------

Variables are names which can hold the result of any expression, usually
values or functions.

Functions stored in variables can be called by invoking the variable
name with an argument.

The keys of sets are similar to variables, and can be extracted into
variables, but they are distinct concepts.

Recursive Sets
--------------

A set's values can refer to variables, but they can't refer to other
keys in the set. Those are keys, not variables.

For example, this doesn't work:

{% highlight nix %}
{ a = 1; b = a; }
{% endhighlight %}

Recursive sets make the set's own keys available as variables within the
scope of the set, including its subexpressions. Recursive sets employ
the `rec` keyword, followed by the usual set notation:

{% highlight nix %}
rec { a = 1; b = a; }
{% endhighlight %}

Note that rec is a keyword, not a variable containing a function.  You
cannot have a variable named "rec".

Let
---

There are no assignment statements in nix, but you can create a new
scope that has "bindings" (another name for assignment) with the `let`
expression:

{% highlight nix %}
let
  a = 1;
  b = 2;
  <...>;
in
  do_something_with a
{% endhighlight %}

Remember that whitespace doesn't matter so you don't need the above
indentation.

The final semicolon in the `let` portion is required.

The `in` portion of the expression has access to the variables defined
in the `let` portion.

The variables are not available to anything outside the `let`
expression, only to the `in` portion.

The variables will mask variables of the same name of an outer scope.

The expression as a whole evaluates to the value of the `in` portion of
the expression.

Note that because there are no assignment statements in nix, you cannot
modify the global scope. You can only create bindings in subscopes.

Lazy Evaluation
---------------

Bindings are only evaluated if they are referenced by the resulting
expression. For example, *b* does not throw a divide by 0 error in the
following expression because it is not referenced by the `in`
expression:

{% highlight nix %}
let
  a = 1;
  b = 1 / 0;
in
  do_something_with a
{% endhighlight %}

Bindings may refer to other bindings within the same `let`, but again,
since they are only evaluated when referenced by the `in` expression,
order doesn't matter. For example, the following is fine, even though
*a* refers to *b* before *b* is defined:

{% highlight nix %}
let
  a = b;
  b = 1;
in
  do_something_with a
{% endhighlight %}

Within container types (sets and lists), values are only evaluated
insofar as they reach another container type and no further. So only
functions, operations and basic values are evaluated upon reference.

The unevaluated elements of container types become further evaluated
when their key (or list element) is referenced directly.

With
----

As a convenience, you can extract the keys of a set into variables via
the `with` expression:

{% highlight nix %}
with { a = 1; b = 2; }; do_something_with a
{% endhighlight %}

The variables *a* and *b* will be in scope for the `do_something_with a`
expression, similar to the `in` portion of a `let` expression.

Further `with` expressions inside the second portion of an outer `with`
can mask variables created by the outer with.

Variables created via `with` will not, however, mask variables created
by an outer `let` expression, a recursive set (see below), nor the
global namespace. This can lead to unexpected results, depending on the
environment in which the `with` expression is evaluated.

As an example, try this expression:

{% highlight nix %}
with { builtins = "hello"; }; builtins
{% endhighlight %}

There is no way to extract only a subset of a set's keys via a simple
`with`.

Builtins
--------

I won't go over each of the builtins, but all of the functions available
out-of-the-box with nix are stored in a global set called *builtins*.

You can examine the names of the available functions with:

{% highlight nix %}
builtins.attrNames builtins
{% endhighlight %}

A few builtins are also available directly in the global namespace, such
as `toString`:

{% highlight nix %}
toString ./filename.txt
{% endhighlight %}

Derivations
-----------

Derivations are the set of information needed to classify and build a
package. Derivations are a their own type, layered over a basic set.

Derivations are created with the `derivation` function. It takes, at a
minimum, the set of *name*, *builder* and *system*:

{% highlight nix %}
derivation { name = "myname"; builder = "mybuilder"; system = "mysystem"; }
{% endhighlight %}

The result of this function call is a special set (type: derivation)
which looks like the following:

{% highlight nix %}
{
  all         = [ «derivation /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv» ] ;
  builder     = "mybuilder"                                                             ;
  drvAttrs    = { builder = "mybuilder"; name = "myname"; system = "mysystem"; }        ;
  drvPath     = "/nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv"                ;
  name        = "myname"                                                                ;
  out         = «derivation /nix/store/z3hhlxbckx4g3n9sw91nnvlkjvyw754p-myname.drv»     ;
  outPath     = "/nix/store/40s0qmrfb45vlh6610rk29ym318dswdr-myname"                    ;
  outputName  = "out"                                                                   ;
  system      = "mysystem"                                                              ;
  type        = "derivation"                                                            ;
}
{% endhighlight %}

While it is its own type, it can still be treated as a normal set.

Inherit
-------

The `inherit` keyword in a set definition creates a key with the same
value as the variable of the same name:

{% highlight nix %}
let
  a = 1;
in
  { inherit a; }
{% endhighlight %}

This is the same as:

{% highlight nix %}
let
  a = 1;
in
  { a = a; }
{% endhighlight %}

`inherit` can take multiple arguments:

{% highlight nix %}
let
  a = 1;
  b = 2;
in
  { inherit a b; }
{% endhighlight %}

Packages
--------

A package is typically a function which produces a derivation:

{% highlight nix %}
{ system ? builtins.currentSystem }:
  derivation {
    name    = "myname"    ;
    builder = "mybuilder" ;
    inherit system        ;
  }
{% endhighlight %}

Channels
--------

A channel is a function which produces a set of derivations:

{% highlight nix %}
{ system ? builtin.currentSystem }:
  let
    builder = "mybuilder";
  in
    {
      package1 = derivation { name = "package1"; inherit builder system; };
      package2 = derivation { name = "package2"; inherit builder system; };
    }
{% endhighlight %}

Typically a channel is constructed with package imports which are then
invoked with an argument, since packages are functions that produce
derivations, rather than direct derivation calls as shown here.

Import
------

The import keyword expression loads the expression in the given file:

{% highlight nix %}
import ./expression.nix
{% endhighlight %}

The expression in the file is returned as if it had been source code in
place of the import expression, with one important difference. The
imported expression cannot see any outer scopes except for the global
scope.

Because of this, most file-based expressions are functions, so anything
they need from the outer scope can be explicitly passed to them.

Importing a directory path causes the file `default.nix` in that
directory to be loaded.

For example, the following expression loads the file `default.nix` from
the same directory in which the expression's own file is located:

{% highlight nix %}
import ./.
{% endhighlight %}

Resources
---------

That is a brief survey of the most important facets of the nix language.

There are many other important features and details, such as how
builders work, the `mkDerivation` helper, *if then else* expressions and
more.

Some good sources of information include:

-   the [nix pills] series

-   the nix expression language [documentation]

-   the [nix wiki]

-   this [tutorial] blog post

The nix-repl referenced at the beginning of the cheatsheet is an
invaluable tool for learning the ins and outs of the language.

Finally, there is a dated but illuminating description of an early form
of the nix language [grammar].

  [nix pills]: https://nixos.org/nixos/nix-pills/
  [documentation]: https://nixos.org/nix/manual/#ch-expression-language
  [nix wiki]: https://nixos.wiki/
  [tutorial]: https://medium.com/@MrJamesFisher/nix-by-example-a0063a1a4c55
  [grammar]: https://nixos.org/releases/nix/nix-0.5/manual/manual.html#id2526745
