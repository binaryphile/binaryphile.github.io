---
layout: post
title:  "A Vagrant Box for Spree Development"
date:   2012-12-13 00:00:00 +0000
categories: spree
---

[Vagrant] is a way to automate the management of [VirtualBox] VMs.
Spree is an open-source e-commerce solution written in Ruby on Rails.

If you're looking to get started with Spree development, it can be a bit
intimidating to get a development environment working.  I'll show you
how to easily get an up-to-date, fully-functional and replicable
development environment going in less than an hour.

If you're a Rails developer not working with Spree, this environment
should also work great for you as well, it's just custom-tailored to
include Spree's requirements.

What You Get
============

The end result of using this is a VirtualBox vm running Linux 12.04.1
LTS, with a fully configured development environment under the vagrant
user.

Benefits
========

There are several benefits to using vagrant for Spree development.

Standard development environment preconfigured

: All of the prerequisites for a working Spree environment are
installed, including RVM, ImageMagick, MySQL and all dev libraries.

Latest software

: When vagrant builds the environment for the first time, the latest
available versions are installed.

Platform independence

: The files for your project reside on your system and are shared with
the vm through VirtualBox's shared folder facility.  This allows you to
work on project files in your regular editor on your native system and
immediately see the results in the vm's runtime environment.  You can do
pretty much everything except debug on your native system.

: I should note, however, that the convenience of the shared folders
feature comes at a price.  Afer having used this configuration for a
while, I became dissatisfied with the performance of my box.  I tweaked
a few things with no luck, until I thought to copy the files from
`/vagrant` to my home directory and run from there.  What a difference.
If you're on Linux or MacOS, you may be able to use NFS to achieve
shared files without relying on the non-performant shared folders in
virtualbox.  You can find a suggestion here:
<http://www.uvd.co.uk/blog/labs/setting-up-a-debian-virtualbox-for-web-development/>

: Since my host is Windows, I don't have NFS, so instead I'm
investigating Dropbox within the guest as my sharing solution, using a
Dropbox account dedicated for the purpose so I don't download my entire
Dropbox into the vm.  I'm using this post:
<http://rbgeek.wordpress.com/2012/08/19/how-to-install-and-configure-dropbox-on-ubuntu-server-12-04-lts/>

Usage
=====

Usually you create and run a completely separate vm environment for each
project you're working on.  There's no potential for one project's setup
to adversely impact any other's that way.  Every project gets a clean
environment over which it has full reign.

When you bring up the vm, it has access to the directory you created it
in, so you can make a new Spree instance or clone your existing one into
a subfolder and work with the files on your native machine.  You only
need the vm to run and debug the code.  Even the browsing is done with
your native machine's browser by pointing it to `localhost:3000` when
your app is running.

Since the vm already has everything you need, you can create your vm,
connect to it, `cd /vagrant`, clone your project, make sure you
have database.yml properly configured, `bundle install`, `bundle
exec rake db:bootstrap` and `bundle exec rails s`.  On your native
machine, browse to localhost:3000 and that's it!  You've got a
working Spree sample store!

Of course, importing your database or creating a new store installation
requires more steps than that, but the idea is that the vagrant vm
completely eliminates the timesink that is setting up a new machine
environment.

Platforms
=========

Vagrant works on Windows, MacOS and Linux, since it is based on Ruby and
VirtualBox.  There are even one-step installer packages available.

Spree runs best on Linux or MacOS.  I'm a Windows user myself, so
imagine my disappointment to learn how difficult it was to get Rails
working well in this environment.  Every new Ruby release poses its own
challenges, and it's just terribly slow even after you figure out how to
work around the bugs and native compilation issues.

Fortunately, that's what gave me the impetus to make a vagrant
configuration in the first place, since it's easy and fun to develop in
Linux with Rails, and vagrant gives you the best bridge between Windows
and Linux.

Prerequisites
=============

- Download the latest [VirtualBox] for your platform
- Download the latest [Vagrant] for your platform
- Download the [Ubuntu 12.04.1 LTS] box
    - If you can't run 64-bit vms, then try this [32-bit Ubuntu]
    instead.  Import it as `precise32` and change the name of the box in
    the Vagrantfile to match.
- Save [this text] into a file called `Vagrantfile`

Be aware that the Ubuntu LTS server is ssh command-line only, no gui.
This is to match the recommended deployment environment for Spree, as
well as to minimize resource usage.  You should be able to choose a
different box if you'd like and still have the process work, as long as
you change the box name in the Vagrantfile.

### Windows-specific prerequisites

- Download the [Putty] setup exe

Instructions
============

Install VirtualBox

: You shouldn't really need them, but you can find the [VirtualBox
installation instructions here].

Install Vagrant

: You shouldn't really need these either, but you can find the [Vagrant
installation instructions here].

Windows: Install Putty

: You get the idea.  Here's the [Putty documentation].

Install Vagrant's VirtualBox Guest Additions upgrader

: If you installed Vagrant from an installer, do:

: `vagrant gem install vagrant-vbguest`

: If you installed Vagrant as a gem, do:

: `gem install vagrant-vbguest`

Windows: Import the ssh key

: - From the Start menu, open _Putty > Puttygen_
- Click the _Load_ button for _Load an existing private key file_
- Go to the `.vagrant.d` folder under your user profile directory (on
  Windows 7, usually `C:\Users\[YourProfileName]`)
- Show all files and select `insecure_private_key`
- Click _Open_
- Click _OK_ to the Puttygen notice
- Click _Save private key_ for _Save the generated key_
- Click _Yes_ to the Puttygen warning
- Create a `.ssh` folder under your profile directory if there isn't one
  already and save the file as `vagrant.ppk`

Windows: Start Pageant automatically with key

: Pageant is a key manager that will allow you to log onto your vagrant
box without needing to enter a password, via Putty's ssh.  You'll want
it started automatically when you boot so managing vagrant boxes is
seamless.

: - From the Start menu, right-click _Putty > Pageant_ and select _Send
to > Desktop (create shortcut)_
- On the desktop, right-click the _Pageant_ icon and select _Properties_
- On the _Shortcut_ tab, click to put the cursor at the end of the
  _Target_ field and add the full path to the ppk file you saved
  (including a space after the pageant exe) - you may need to enclose
  this in quotes if you have a space in the ppk file path
- Click _OK_ to close the properties dialog
- Cut and paste the Pageant shortcut from your desktop to the _Startup_
  folder in the Start menu
- Click the Pageant shortcut to start Pageant now

Install the required chef recipes

: You'll need the apt, build-essential, git, mysql, ohmyzsh, openssl,
  rvm and system_packages recipes.

: - Decide where your vagrant project directory will go
- Make a sibling directory called `my-recipes`
- Under that, make a directory called `cookbooks`
- From `cookbooks`:
    - `git clone git://github.com/opscode-cookbooks/apt.git`
    - `git clone git://github.com/opscode-cookbooks/build-essential.git`
    - `git clone git://github.com/opscode-cookbooks/git.git`
    - `git clone git://github.com/opscode-cookbooks/mysql.git`
    - `git clone git://github.com/binaryphile/chef-ohmyzsh.git ohmyzsh`
    - `git clone git://github.com/opscode-cookbooks/openssl.git`
    - `git clone git://github.com/fnichol/chef-rvm.git rvm`
    - `git clone git://github.com/coroutine/chef-system_packages.git
      system_packages`

Import the vagrant box

: - Open a command-line prompt in the directory containing the
downloaded vagrant box and run:

    `vagrant box add precise64lts precise64.box`

: The name is coded into the Vagrantfile, so don't change it unless you
also change it there.

: You can delete the downloaded box when you're done.

Create the vm

: - Create a directory for your vm and open a command line there
- `vagrant init`
- Copy the Vagrantfile to the vagrant directory (make sure you do this
  _after_ `vagrant init`)
- `vagrant up`
- Wait for the process to complete

: It will take a while for this step.  Go get a cup of chai.  You can
see an example of [the output of this step on my system here].

: Here's a rundown of what it's doing:

: - Booting the vm
- Upgrading VirtualBox Guest Additions
- Rebooting the vm
- Updating apt and the caches
- Installing:
    - mysql with dev libraries
    - build-essential
    - zsh
    - oh-my-zsh
    - rvm (user installation)
    - ruby 1.9.3 latest
        - <del>Note: I've had problems with Ruby 1.9.3-p362.  You may want to edit the Vagrantfile to specifically install "1.9.3-p327".</del>  
          Ruby 1.9.3-p374 has been released and fixes the p362 issue, so you can probably use Vagrantfile unchanged.
    - imagemagick with dev libraries (libmagickwand-dev)
    - ranger
    - tmux
    - vim
- configuring the root mysql user with no password

: Note that rails is not installed, but bundler is, so your project will
install the proper rails version with `bundle install`.  If you're
starting a new project though, you'll need to run `gem install rails -v
[whatever]` once you're connected to the machine, however.  Don't forget
to use whatever gemset configuration you desire first, if you use
gemsets.

Optional: Repackage the vm or remove the chef configuration

: The only issue with using this Vagrantfile is that chef verifies the
installed software every time the vm is started, adding to the start
time.  If you are planning on reusing this vm, I recommend repackaging
it as your new base box.  If this is a single-purpose vm, you can just
remove the chef configuration instead.

: ### Repackage the vm

: - If it's running, stop the vm with `vagrant halt`
- `vagrant package -o precise64spree.box`
- `vagrant box add precise64spree precise64spree.box`
    - You can delete `precise64spree.box` at this point if you want
- Destroy the current box with `vagrant destroy`
    - Answer yes when asked to confirm
- Replace the contents of `Vagrantfile` with this:  

: ~~~
Vagrant::Config.run do |config|
    config.vm.box = "precise64spree"
    config.vm.forward_port 3000, 3000
end
~~~

: - Start the vm based on the new box with `vagrant up`

: The box will have to be recopied, so this will take a few moments.
Also, I'd keep the older `precise64lts` box around in case you ever want
to rerun the process to update all of the software

: ### Remove the chef configuration

: If instead you want to keep the vm the way it is but skip the chef
check on startup, just comment all the lines in the Vagrantfile
pertaining to chef configuration.

Connect to the vm

: If you are on Linux or MacOS, run `vagrant ssh`.

: If you're on Windows, run Putty.  In the connect to parameters, use
`vagrant@localhost` as the address and port 2222.  At this point, you'll
want Pageant running as detailed earlier in the post.

: You can save this configuration with the name `vagrant` so you can
always connect to your projects by double-clicking the saved name.  If
you want to create a shortcut, copy the Putty one and add the parameters
`-load vagrant`, then rename the shortcut to `vagrant`.

Clone or create your project

: - `cd /vagrant`

: __To clone it:__

: - `git clone [project url]`
- Make sure your Gemfile is set to work with mysql (`gem 'mysql2'`)
- Make sure your Gemfile has v8, which is necessary on linux (`gem 'therubyracer', platforms: :ruby`)
- If necessary, update `config/database.yml` to point to mysql with user
  `root` and no password
- `bundle install`
- `bundle exec rake db:bootstrap` and answer the questions in the
  affirmative
    - This creates the sample data and pictures.  Instructions for
    importing real store data are outside my scope here.
- `bundle exec rake assets:precompile:nondigest`
- `bundle exec rails s`

: __To create it:__

: - Create a gemset if you so desire
- `gem install rails -v [version]`
- `rails new [project] -d mysql`

: If you're creating a new Spree project, follow the [installation
instructions here] for the complete installation.  You won't need to
modify your `config/database.yml` because it's set up to work with the
vm's mysql by default.

Once you've got rails running, go back to your native system and point
your browser at `localhost:3000`.  Enjoy working with your Spree vm!

Final Notes
===========

You can only have one vm running at a time since they are all configured
to forward the same ssh and web ports.  Learn the vagrant commands for
starting, halting, suspending and resuming your vms.

To see what's running, you can always fire up the regular VirtualBox
management interface.  You should check it every once in a while to make
sure you don't have any unwanted vms cluttering up your disk.
VirtualBox keeps the vms in its own configured vm directory.

These instructions tell you how to set up your project in a subfolder of
the vagrant folder.  This is the most straightforward and flexible
setup.  For a flatter structure, you can set up your project directly in
the vagrant folder, but because that's trickier in some cases I haven't
tried writing the instructions for that.

In particular, if you're working on the source of an extension or of
Spree itself, you'll want to use the subfolder model so you can have an
instance folder as a sibling.  The instance can point its Gemfile to the
sibling paths like so:

    gem 'spree', path: '../spree'

Any changes you make to the source will then change the running
instance.  Just make sure that you set the source to the proper commit
expected by your instance's Gemfile.lock before you branch for your own
development.

Happy Spreeing!

[VirtualBox]: https://www.virtualbox.org/wiki/Downloads
[Ruby]: http://www.ruby-lang.org/en/downloads/
[RubyInstaller]: http://rubyinstaller.org/downloads/
[Vagrant]: http://downloads.vagrantup.com/
[Ubuntu 12.04.1 LTS]: http://dl.dropbox.com/u/1537815/precise64.box
[32-bit Ubuntu]: http://files.vagrantup.com/precise32.box
[this text]: https://gist.github.com/raw/4260060/a17328cfd6ca011ef6b16f904a401ec0ecc5fb70/Vagrantfile
[Putty]: http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
[VirtualBox installation instructions here]: https://www.virtualbox.org/manual/ch02.html
[Vagrant installation instructions here]: http://vagrantup.com/v1/docs/getting-started/index.html
[Putty documentation]: http://the.earth.li/~sgtatham/putty/0.62/htmldoc/
[the output of this step on my system here]: https://gist.github.com/4348104
[installation instructions here]: http://guides.spreecommerce.com/getting_started.html
