---
layout: post
title: "Customizing Bash"
date: 2020-07-12 12:00 UTC
categories: [ bash ]
---

If you're interested, start the series with [part 1].

In the [last part], we learned how to get the latest bash, especially if
you're on a mac.

This time (and for the next few) let's talk about how I customize bash.

Bash has a lot of settings that don't have great defaults.  For example,
bash keeps track of your command history by default, but it doesn't hold
very many commands.  That doesn't give you a lot of time to fetch
something from your command history before it's lost for good.  The bash
history is kept in a file in your home directory, and disk space is
cheap, so why not keep thousands of your past commands?

Bash also has the ability for you to create your own commands via
functions and aliases.  Functions and aliases are close to the same
thing.  While aliases are much more limited, they are easier to write,
so they both have their place.  I add a lot of aliases and functions to
make frequently-used commands shorter and complicated commands simpler.
One example is to add a shorter version of the **ls** command with the
options I like: `alias ll='ls -al'`.  One thing I like to note about
making aliases is that I never replace the basic command itself, i.e. I
never make an alias called **ls**, because I never want to be surprised
by the behavior of the basic command on a system which doesn't have my
aliases.

Other reasons to customize bash include:

-   setting useful environment variables

-   adding initialization required by installed packages

-   fun and profit

As I began to tweak bash's configuration, it became more and more
complex and my initialization files became longer and longer.  Not only
that, bash has multiple initialization files which are for different
purposes and are loaded at different times.  It can be quite confusing.
If you want to know how much, take a look at this diagram of [when
the various files are loaded].

![diagram](https://www.solipsys.co.uk/images/BashStartupFiles1.png)

Would you believe that this diagram isn't even complete?

In any case, there's quite a bit to absorb.  Let's not try to take
everything in one bite.  In particular, let's gloss over the stuff that
isn't that important.  There are a few things I've worried about in my
initialization files:

-   putting different kinds of settings in separate, well-named files

-   version control and synchronization with git

-   customizing the same set of files for different systems easily

-   using a single file as a starting point, rather than separate
    profile and rc files

-   validating that the settings have actually taken effect

That's enough for an overview.  See the [next part] for more details.

  [part 1]: {% post_url 2020-07-02-how-i-bash-a-new-series %}
  [last part]: {% post_url 2020-07-06-getting-bash %}
  [when the various files are loaded]: https://www.solipsys.co.uk/images/BashStartupFiles1.png
#  [next part]: {% post_url 2022-01-08-environment-variables %}
