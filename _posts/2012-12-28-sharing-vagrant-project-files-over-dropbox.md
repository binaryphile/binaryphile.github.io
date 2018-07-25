---
layout: post
title:  "Sharing Vagrant project files over Dropbox"
date:   2012-12-28 00:00:00 +0000
categories: vagrant
---

Why would you want to share vagrant project files over Dropbox?  What
are Vagrant project files anyway?

[Vagrant] is a way to automatically manage virtualbox vms on your local
machine.  I use vagrant primarily to give me clean linux environments in
which to run my rails projects.  Since I'm on windows and windows
doesn't run rails very well as of right now, it makes developing much
more pleasurable.

The nice thing about vagrant is that it's project-centered, meaning it
stores its configuration in the project directory (text files which are
separate from the vm its managing.  The vm disks are still in vb's
normal folder).  This directory gets shared into the vm, so if I
also stick my rails project in a subfolder, the same files are visible
to both the vm and my local system.  Thus I can work on the rails files
with my familiar local editor and have the results show up instantly in
the linux vm which is my run-time environment.

Of course, I work on more than one machine, moving from work to my home
machine to my laptop.  If I'm in the middle of something, I want that
work to follow me as well, which is why I use dropbox.

Dropbox is great at syncing small files.  However, vms pose a problem
because even a small change means resyncing an entire disk, which is
time-prohibitive.  What I want is for my project files to be synced
automatically while keeping the run-time environment (the vm) separate.
Vagrant makes it easy to set up nearly identical run-time environments
on all of my machines without requiring me to sync the actual vms over
dropbox.  Even the vagrant configurations get synced because they are
just text files.

Of course, the resulting vms do get out of sync because they aren't
exactly the same files.  If I install any software after booting the
machine, it won't be installed elsewhere unless I also visit and install
on the other machines.  The solution to this is to add the software to
my template machine and repackage with vagrant, then download it to my
other machines.  Since the effort of getting the rails project up and
running on a brand new vm is minimal, it's easy just to destroy and
recreate the vms based on the new template.

The data in the database can also get out of sync.  Fortunately I'm
working with sample datasets in development most of the time, so it's
automatically generated in an identical fashion and doesn't matter too
much anyway.  But when I need real store data for debugging purposes,
for example, it's usually not a big deal to do a mysqldump to a
text file and just put that in the project directory as well, so it's
automatically synced to my other machines.  I'm not working with big
datasets, so that works fine.  I just have to remember to reimport to
mysql whenever I change data and switch machines.

I also have to make sure that virtualbox is the same version on each
machine so that they don't fight over which version of guest additions
to install (I have the auto-updating turned on through `vagrant gem
install vagrant-vbguest).

So far so good.  The one issue that's been difficult to solve, however,
is that whenever I create a vm on one machine, then do the same on
another, virtualbox is unaware of the vm on the original machine and
assigns a new machine uuid to the vm.  Vagrant stores this uuid in the
project directory in the `.vagrant` file.  Thus, when I go back to the
first machine, the machine uuid of the original vm has been overwritten
and lost, so it can't find the existing vm and creates a new one.  This
makes a perpetual cycle of losing the existing machine's uuid between
platforms.

To solve this, you need to get your various machines to agree on a
machine uuid for the vagrant vm.  Here's my method.

- Create the vm on your first machine with `vagrant up`
- `vagrant halt` the vm
- In the project directory, make a copy of `.vagrant`
- Create the vm on your second machine with `vagrant up`
- `vagrant halt` the vm
- Open the original `.vagrant` (the one you copied) file in a text
  editor and copy the uuid (minus any quotes)
    - This should look like `85a3496f-b51e-407b-b270-d0c7fbee2b01` (but
    not that exact one, look for the one in your file)
    - Don't mix up the vm uuid for the disk uuid
- Copy the original `.vagrant` over the new one, overwriting it
- Make sure there are no virtualbox processes running - _VBoxSVC.exe_ is
  one that tends to stick around for a while after you close virtualbox,
  so make sure it's gone
- In your home directory, find `.Virtualbox\Virtualbox.xml` and open in
  a text editor
- Find the `MachineRegistry` key with the same name as your project and
  replace the uuid with your copied one
- In the virtualbox vms folder (usually `VirtualBox VMs` in your home
  directory), find your machine folder with your project name and open
  `[project name].vbox` in a text editor
    - Note there will be a random number tagged onto your project name
- Find the `VirtualBox/Machine` key and replace the uuid attribute with
  the one you copied

You only need to do this on the machine with the second vm, since you're
pasting the uuid that the first is already configured with.

Before trying to start the new vm, verify that the uuid has taken
effect.  Use the `vboxmanage` command to list the vms:

    vboxmanage list vms

If you get a message about the vm being inaccessible, there was probably
a virtualbox process sticking around that overwrote one or both of the
files you changed.  Check them again and if the uuid has changed, fix
it.

You should now be able to start the vm on either machine without losing
your existing vm.

[Vagrant]: http://www.vagrantup.com/
