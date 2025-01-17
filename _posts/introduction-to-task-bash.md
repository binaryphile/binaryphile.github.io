---
layout: post
title: "An introduction to task.bash"
date: 2025-01-17T00:00:01Z
categories: [bash]
---

While I love computers, I don't love having to deal with computer lifecycles.  When you have
multiple machines, it gets worse.  Your first machine is set up just how you like...all the
right tools installed, dot files that put all of your command aliases at your fingertips,
editor configurations, etc. etc. etc.  Now add another machine, and go through all of those
steps...again.  And then again for a third machine.  Now platform differences and
configuration drift over time matter.  The platform makes you install slightly different
packages, and use slightly different command aliases.  Different versions of the same
software drift and require different settings.  etc. etc. etc.

Now a machine dies or is dying.  You need to go through the process again with its
replacement.  While a new machine brings the optimism of a new start, it is accompanied by
the sinking feeling that there is much work to do.

Long ago, I adapted my dot file setup to handle different environments and versions of
software configuration.  This is not a blog post about cross-platforms dot files or
`.bashrc`, although it certainly helps if you already have your own solution for that
problem.

It's a post about how to get from a brand-new OS to a system configured the same as the rest
of my systems and the tool I wrote to assist in the task, called `task.bash`.

`task.bash` is a Bash shell library.  When you are using it, you are just writing a bash
script according to some conventions and calling a handful of its functions.  Using it
allows you to write installation scripts (called runners) that can do things like update the
system via the package manager, download files, create git repository clones, link files and
run other commands.  This allows you to configure your system reliably and quickly, even
when you are applying the runner to a machine that has been partially configured or is
configured, but configurations have changed and it needs updating.

In the past, I had a solution to this issue already.  It was Ansible.  Ansible is a
venerable tool for system configuration management that runs on playbooks.  Playbooks are
declarative yaml files that specify what to do.  Ansible runs on modules that know how to do
specific tasks, like copy files or create symlinks, and each one can be invoked and provided
with parameters.

"Declarative" is highly subjective in this case.  I don't see Ansible files as declarative
in the least.  What it really means is, you get a single function (the module) with its
defined parameters, and the modules are designed to be general enough to do anything you
might want to accomplish *in a single invocation*.  If it were truly declarative, order
would not matter for Ansible, but in reality it does.  Playbooks are a yaml-based script
where the commands are canned (but curated) library and the rest of the system is hidden
from you.

So, the time came to replace my daily driver machine.  My setup is a bit eclectic.  While I
am no longer a fan of Google (remember "Don't be evil?"), I am a fan of Chromebooks.  Lots
of choices of machine, good battery life, value-oriented price and specs, and most of all,
zero-fuss, reliable OS upgrades.  My weapon of choice at the moment is an Acer Spin 713, an
older model but one sufficient for Go development at 16GB RAM, a decent i5 processor and a
3:2 aspect ratio screen that gives added height for vertical viewing.
