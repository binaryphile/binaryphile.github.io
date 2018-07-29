---
layout: post
title:  "Approach Bash Like a Developer - Part 1 - Intro"
date:   2018-07-26 00:00:00 +0000
categories: bash
---

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

With a single text file, in the form of a bash script, and zero
software-installation-required, I feel confident stating that you can
reach largest set of compatible computing environments in the world with
bash.

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
do what you're trying to do with bash. Without comdemning individuals,
that channel is, on the whole, stuck on itself.

In general I would also say not to listen to anyone who tells you to not
do this or that with bash. So long as you are trying to learn, no one
should be warning you about "the way of pain" or any other such BS.

To be fair, you shouldn't implement things in bash where it's
unwarranted, such as complicated programs for your day-job, or when
someone else needs to maintain it. But if it's for your own edification
then, by all means, full steam ahead.

The point of this series is to teach the mindset which avoids the
pitfalls intimated by such ominous warnings in the first place, while
enabling you to enjoy the experience of learning the numerous ins and
outs of this challenging and, sometimes, rewarding language. Haters be
damned.

Now for the good stuff:

-   [the bash hacker's wiki] - the best explanation of the details of
    bash's operation

-   [the google shell style guide] - a reasonable starting point for
    learning about style, but take with a big grain of salt. It was
    written for Google employees, not the community.

-   [one of the "awesome shell" lists] - a jumping-off point for further
    exploration

Continue with [part 2] - vim.

  [the bash hacker's wiki]:           http://wiki.bash-hackers.org/
  [the google shell style guide]:     https://google.github.io/styleguide/shell.xml
  [one of the "awesome shell" lists]: https://github.com/alebcay/awesome-shell
  [part 2]:                           {% post_url 2018-07-26-approach-bash-like-a-developer-part-2-vim %}
