---
layout: post
title:  "Approach Bash Like a Developer - Part 1 - Intro"
date:   2018-07-26 00:00:00 +0000
categories: bash
---

Update: For examples of my coding approach, I've written solutions to a
number of the exercism [bash exercises] that you can inspect.  They
won't all make sense until you've gone through most of the series, but
they're a good resource to examine these techniques in action.

This is part one of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

I hope to pump out a number of these. They will be small in scope, but I
have a lot to cover. There is a lot that can be done with bash if you
adopt a number of strategies, and they add up.

By the end of the series, my goal is to outline enough techniques such
that you can effectively build command-line utilities as well as small
programs in bash.

In part one, I'll discuss what bash is suitable for, as well as a couple
of resources that can arm you with the proper information to be
successful with it.

Bash - Huhh - Good God Y'all - What is it Good For?
---------------------------------------------------

There's a justifiable love/hate relationship to be had with bash as a
programming language. Bash's warts will be the focus of the remainder of
the series, so let's look at its good points for the moment. To say it's
good for "absolutely nothing" would certainly be unfair.

Of course, there is plenty of competition from the likes of perl,
python, ruby, zsh, powershell and other shell languages. I won't spend
much time comparing it to other languages...suffice to say that they all
have their quirks, but most of them are better-designed than bash as
general-purpose scripting languages. I'm not claiming otherwise.

So what are bash's good points?

### Simplicity

Bash is a very simple language. It has a few data types which are
weakly-typed, which makes it simple to declare and use variables.

It is primarily oriented around strings as a data-type, which is
convenient since it is mostly processing arguments and passing strings
between external programs.

It makes some convenient container types available, such as arrays,
which are dynamic, and associative arrays, which I will call hashes.
These make handling sets of information with distinct elements easier.

It only has the basic control structures which you would expect from a
programming language, such as for loops. If you know any other
mainstream language, there are no surprises in the catalog. No
object-oriented or functional programming tricks to learn here.

Bash has a limited set of builtin functionality which is extended by the
ability to easily call external programs. There's no standard library
aside from what is builtin or distributed on most unix systems.

Bash doesn't have a standard packaging system nor language support for
modules. Nor does it have a standard logging system.  While these are
minuses for functionality, they're also pluses for simplicity.

### Ubiquity

Simply put, bash is everywhere. The vast majority of unix distributions
either come with bash as the default shell, come with it installed on
the system, or have it available to install. Even MacOS and, now,
Windows have system support for bash.

Only python 2 enjoys anywhere near that level of presence on systems
everywhere, and not nearly so much as bash.

With a text file in the form of a bash script and nothing else required,
I feel it's fairly likely that bash provides the largest installed base
of run-time environments in the world.

### Command-line Orientation

The weirdness of bash comes mostly from the fact that it is built to do
one thing extremely well...call other command-line programs while
staying out of your way.

If you want to control a unix system, there is no tool like the
command-line. While many management tools are available for unix, none
of them are as capable as the raw command-line. The cli is the
first-supported interface for virtually any unix tool and also the best
supported.

This makes bash the essential and standard tool for interacting with
these other tools programmatically, especially when it is necessary to
coordinate with more than one of them at a time. Python is sometimes
referred to as a "glue" language, but bash embodies this idea better
than python.

And as clunky as bash can seem, using other (non-shell) scripting
languages to run a bunch of cli commands is far more clunky and probably
a mistake.

### Conciseness

Once you've learned a small set of bash's operations, mostly string
manipulation expressions, bash can allow you to be far more concise with
your code than many other languages.

This is, of course, a double-edged sword, because conciseness can also
mean opacity to the uninitiated. "Your code looks like line noise," is a
charge often leveled at languages such as perl, or bash in the hands of
an expert.

I, however, view it as a major plus. While I still occasionally
encounter head-scratchers in others' code, I enjoy the fact that
knowledge of a few standard idioms allows me to read more code in one
screen of bash than in many other languages. It allows me to read and
write quickly.

That's about the size of it. I wish there were more reasons to love
bash, because I actually enjoy programming with it quite a bit, although
I am somewhat of a glutton for punishment.

Resources for Learning About Bash
---------------------------------

As a quick aside, I would not recommend the freenode \#bash channel.
It's not particularly friendly to newcomers to the language, and you're
definitely in for at least one lecture on why you shouldn't be trying to
do what you're trying to do with bash.

I also would not recommend the Bashism wiki.  It's full of good
information tinged with inaccuracies, bad opinions and outright bad
advice.  Bash is better than they make it out to be, and you deserve
better too.  There's nothing there you can't find elsewhere.

In general I would also say not to listen to anyone who tells you to not
do this or that with bash. So long as you are trying to learn, no one
should be warning you about how you will regret things or other such BS.

To be fair, I agree that you shouldn't implement things in bash where
it's unwarranted, such as complicated programs for your day-job, or when
someone else needs to maintain it. But if it's for your own edification
and won't require others to get on the merry-go-round with you, then, by
all means, full steam ahead.

The point of this series is to teach the mindset which avoids the
pitfalls intimated by such ominous warnings in the first place, while
enabling you to enjoy the experience of learning the numerous ins and
outs of this challenging and, sometimes, rewarding language.

Now for the good stuff:

-   [the bash hacker's wiki] - the best explanation of the details of
    bash's operation

-   [the google shell style guide] - a reasonable starting point for
    learning about style, but take with a big grain of salt. It was
    written for Google employees, not the community.

-   [one of the "awesome shell" lists] - a jumping-off point for further
    exploration

Continue with [part 2] - vim.

If you want to jump ahead to any specific topic, here's a table of
contents for the series:

-   [Part 1 - Intro]
-   [Part 2 - Vim]
-   [Part 3 - The Start]
-   [Part 4 - Failure!]
-   [Part 5 - Success!]
-   [Part 6 - Outline Script]
-   [Part 7 - Sourcing]
-   [Part 8 - Support Library]
-   [Part 9 - Another Test]
-   [Part 10 - Test Independence]
-   [Part 10.5 - Aside on Aliases]
-   [Part 11 - Strict Mode]
-   [Part 12 - Working in Strict Mode]
-   [Part 13 - Implementing Strict Mode]
-   [Part 14 - Updated Outline]
-   [Part 15 - Strict Mode Caveats]
-   [Part 16 - Recap]
-   [Part 17 - Command Processing]
-   [Part 18 - Word Splitting]
-   [Part 19 - Disabling Word Splitting]
-   [Part 19.5 - Disabling Path Expansion]
-   [Part 20 - Scoping]
-   [Part 21 - Environment Variables]
-   [Part 22 - Data Types]
-   [Part 22.5 - Naming and Namespaces]
-   [Part 23 - Passing Arguments]
-   [Part 24 - Passing Arrays]
-   [Part 25 - Passing Hashes]
-   [Part 26 - Returning Values]
-   [Part 27 - Traps]
-   [Part 28 - Tracebacks]
-   [Part 29 - Debugging]
-   [Part 30 - Option Parsing]
-   [Part 31 - getopt]
-   [Part 32 - Parallelism]
-   [Part 33 - Modules]
-   [Part 34 - Indirection]
-   [Part 35 - Recursion]
-   [Part 36 - Functional Programming]

  [Part 1 - Intro]: /bash/2018/07/26/approach-bash-like-a-developer-part-1-intro.html
  [Part 2 - Vim]: /bash/vim/2018/07/26/approach-bash-like-a-developer-part-2-vim.html
  [Part 3 - The Start]: /bash/2018/07/26/approach-bash-like-a-developer-part-3-the-start.html
  [Part 4 - Failure!]: /bash/2018/07/28/approach-bash-like-a-developer-part-4-failure.html
  [Part 5 - Success!]: /bash/2018/07/29/approach-bash-like-a-developer-part-5-success.html
  [Part 6 - Outline Script]: /bash/2018/07/30/approach-bash-like-a-developer-part-6-outline-script.html
  [Part 7 - Sourcing]: /bash/2018/08/04/approach-bash-like-a-developer-part-7-sourcing.html
  [Part 8 - Support Library]: /bash/2018/08/04/approach-bash-like-a-developer-part-8-support-library.html
  [Part 9 - Another Test]: /bash/2018/08/05/approach-bash-like-a-developer-part-9-another-test.html
  [Part 10 - Test Independence]: /bash/2018/08/06/approach-bash-like-a-developer-part-10-test-independence.html
  [Part 10.5 - Aside on Aliases]: /bash/2018/08/23/approach-bash-like-a-developer-part-10.5-aside-on-aliases.html
  [Part 11 - Strict Mode]: /bash/2018/08/09/approach-bash-like-a-developer-part-11-strict-mode.html
  [Part 12 - Working in Strict Mode]: /bash/2018/08/09/approach-bash-like-a-developer-part-12-working-in-strict-mode.html
  [Part 13 - Implementing Strict Mode]: /bash/2018/08/12/approach-bash-like-a-developer-part-13-implementing-strict-mode.html
  [Part 14 - Updated Outline]: /bash/2018/08/13/approach-bash-like-a-developer-part-14-updated-outline.html
  [Part 15 - Strict Mode Caveats]: /bash/2018/08/13/approach-bash-like-a-developer-part-15-strict-mode-caveats.html
  [Part 16 - Recap]: /bash/2018/08/24/approach-bash-like-a-developer-part-16-recap.html
  [Part 17 - Command Processing]: /bash/2018/08/25/approach-bash-like-a-developer-part-17-command-processing.html
  [Part 18 - Word Splitting]: /bash/2018/08/31/approach-bash-like-a-developer-part-18-word-splitting.html
  [Part 19 - Disabling Word Splitting]: /bash/2018/09/01/approach-bash-like-a-developer-part-19-disabling-word-splitting.html
  [Part 19.5 - Disabling Path Expansion]: /bash/2018/09/09/approach-bash-like-a-developer-part-19.5-disabling-path-expansion.html
  [Part 20 - Scoping]: /bash/2018/09/01/approach-bash-like-a-developer-part-20-scoping.html
  [Part 21 - Environment Variables]: /bash/2018/09/02/approach-bash-like-a-developer-part-21-environment-variables.html
  [Part 22 - Data Types]: /bash/2018/09/02/approach-bash-like-a-developer-part-22-data-types.html
  [Part 22.5 - Naming and Namespaces]: /bash/2018/09/17/approach-bash-like-a-developer-part-22.5-naming-and-namespaces.html
  [Part 23 - Passing Arguments]: /bash/2018/09/13/approach-bash-like-a-developer-part-23-passing-arguments.html
  [Part 24 - Passing Arrays]: /bash/2018/09/16/approach-bash-like-a-developer-part-24-passing-arrays.html
  [Part 25 - Passing Hashes]: /bash/2018/09/18/approach-bash-like-a-developer-part-25-passing-hashes.html
  [Part 26 - Returning Values]: /bash/2018/09/22/approach-bash-like-a-developer-part-26-returning-values.html
  [Part 27 - Traps]: /bash/2018/09/23/approach-bash-like-a-developer-part-27-traps.html
  [Part 28 - Tracebacks]: /bash/2018/09/24/approach-bash-like-a-developer-part-28-tracebacks.html
  [Part 29 - Debugging]: /bash/2018/09/27/approach-bash-like-a-developer-part-29-debugging.html
  [Part 30 - Option Parsing]: /bash/2018/09/28/approach-bash-like-a-developer-part-30-option-parsing.html
  [Part 31 - getopt]: /bash/2018/10/08/approach-bash-like-a-developer-part-31-getopt.html
  [Part 32 - Parallelism]: /bash/2018/10/11/approach-bash-like-a-developer-part-32-parallelism.html
  [Part 33 - Modules]: /bash/2018/10/16/approach-bash-like-a-developer-part-33-modules.html
  [Part 34 - Indirection]: /bash/2018/10/28/approach-bash-like-a-developer-part-34-indirection.html
  [Part 35 - Recursion]: /bash/2018/10/29/approach-bash-like-a-developer-part-35-recursion.html
  [Part 36 - Functional Programming]: /bash/2018/10/31/approach-bash-like-a-developer-part-36-functional-programming.html
  [bash exercises]:                   https://exercism.io/profiles/binaryphile
  [the bash hacker's wiki]:           http://wiki.bash-hackers.org/
  [the google shell style guide]:     https://google.github.io/styleguide/shell.xml
  [one of the "awesome shell" lists]: https://github.com/alebcay/awesome-shell
  [part 2]:                           {% post_url 2018-07-26-approach-bash-like-a-developer-part-2-vim %}
