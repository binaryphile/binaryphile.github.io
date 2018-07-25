---
layout: post
title:  "Upgrading Spree from 1.2 to 1.3"
date:   2013-01-24 00:00:00 +0000
categories: spree
---

[Spree Commerce] is an open-source e-commerce solution written in [Ruby
on Rails].

Upgrading Spree can be a bit of a challenge sometimes. If there are a
lot of migrations or the Rails version has made major changes, it can go
less than smoothly. On the other-hand, sometimes it's fairly easy.

The usual procedure is goes like this:

Learn what you need to know about upgrading to this release
-----------------------------------------------------------

-   Check the Spree release notes for the version you're upgrading to

-   If you're upgrading more than one minor version, check the notes for
    each release in between

-   Unfortunately, the only way to find the release notes at the moment
    is to go through the [Spree blog] for the release announcements

-   The release notes are usually linked at the end of the release
    announcement

-   The url for the release notes usually follows this template, so you
    can try filling it in:
    http://guides.diditbetter.com/release\_notes\_\[major\]\_\[minor\]\_\[revision\].html

-   Also read the blog release announcements themselves, as sometimes
    they have important upgrade instructions which may be missing from
    the release notes

-   The comments on the blog posts also can contain important
    information from users' upgrade experiences

-   Search the [Google group] for upgrade experiences as well

Go through the routine Rails upgrade process
--------------------------------------------

-   Change the Gemfile to include the new version of Spree

-   If you're using a git branch, switch to the branch for this version

-   Update the Rails version and any other gems if necessary

-   Update or remove any incompatible extensions

{% highlight bash %}
    bundle update
    bundle exec rake railties:install:migrations
    bundle exec rake db:migrate
    bundle exec rake assets:clean
    bundle exec rake assets:precompile:nondigest
{% endhighlight %}

Note that the assets commands are for development, the command is
different for production. They aren't always necessary but you should
run them just in case.

Now run the store with `bundle exec rails s` and verify that everything
is happy.

My way
------

The standard way is pretty good, and if everything works, then you're
done.

During an upgrade, I like to take the opportunity to clean some house,
so I usually rebuild the store with the new version. I do this for a
couple reasons.

As with most stores, there are a lot of customizations I've done to my
app. These range from theme overrides to adding extensions to adding new
functions directly to the app itself. Interspersed with all this in my
git history is all of the maintenance, the little upgrades and
redeployments. The history tends to get incomprehensible and noisy
pretty quickly. Each time I rebuild for a new minor release of Spree, I
take the time to start a new repo and reorganize the current state into
a logical set of changes, grouping, for example, all of the theme
changes over time into one changeset. This gets rid of all of the piddly
maintenance commits as well.

The other reason is to follow the principle of *matching expectations*.
When the Spree developers lay out their upgrade instructions, they
aren't planning for every possible route that you might have gotten to
this upgrade. Typically, the path of least resistance is to provide
instructions that are known to work for the last minor release. The
expectation is that everyone has to do the upgrade to that last release
before they can do this one anyway, so that's the reasonable assumption.

Hidden in this assumption is the idea that you've installed the last
version as a new store, not an upgrade itself. Why is this important?
Because a new Rails app is not the same from version to version. When
you run the `rails new` command with a new version of Rails, you may get
a very different set of files from version to version (usually not, or a
slightly different set). If you are upgrading time and time again, these
underlying files aren't always being updated to reflect the latest Rails
practices, and that delta from the expectation of new Rails files leads
to the possibility of subtle (read: hard to track) misbehavior. Best to
follow the expectation of new Rails files and make a new store.

How do I know? Because I've done it and diffed it against my old store
and seen the differences. Same goes for the database dumps. From version
to version in Rails you get different assumptions in how the files and
database are created. When it's vital to store operation, the Spree
folks will tell you what files need to change and how. The littler stuff
goes by without mention though. So as the inverse of the principle of
least surprise, I follow the principle of matching the developers'
expectations.

Because I make a new store for each minor point release, I include the
minor point release in the name of the store and, by extension, its
repo. However, when the new instance is created, I want it to share the
same internal application name and, more importantly, database instance
settings, so I always create the store with the name `spree_dibs`. This
makes the Rails name consistent. I then rename the directory to
`spree_dibs_[major].[minor]` after creation.

Is this a lot more work than the basic upgrade method? Definitely. It's
trickier as well sometimes. But I strongly prefer having a store whose
history is logical and well-groomed, with a high signal-to-noise ratio.
I also prefer the comfortable feeling of knowing that my instance is up
to the latest Rails and mysql configuration standards.

The basic outline
-----------------

-   Create a new vagrant vm named after the new version

-   Upgrade ruby if available

-   Get the existing Spree instance working

-   Create a new Spree instance for the new version from scratch,
    without extensions

-   Use sample data for now, the goal is to verify that you can get a
    simple, working instance of the new version

-   Add the extensions, verifying and upgrading as necessary

-   Add the app customizations, consolidating the git history in a new
    repo

-   Upgrade the old store instance from the second step

-   Migrate the upgraded data from the old instance to the new and
    verify

-   Deploy, remigrating the latest data from the production instance

-   The production store has to be down while this occurs to prevent
    losing new transactions

During this process I actually have a total of three repos:

1.  A working version of the old store for database upgrade purposes

2.  A non-working (no db necessary) version of the old store for
    purposes of rewriting history and exporting patches

3.  The new store being built

I keep all of this on the new vm, separate from my old development vm.
This is so everything related to the new store is isolated from the old
one. If I need to do a hotfix on the old store mid-stream during this
process, I shut down this vm and fire up the old one to do my fix, then
switch back when I'm done.

Create the new Vagrant vm
-------------------------

I use [Vagrant] to separate my development environments, so the first
thing to do is create a new vagrant project. I've written a [separate
post] on how to get my existing Spree instance cloned and running, and
that's the first step.

When you create the vm, make sure you get the copy of the existing
instance running. However, don't use the regular development name for
your database, instead change the development database name to
`spree_dibs_upgrade` in `config/database.yml`. This is so you can have
the old store and db available for the schema updates and still have a
separate new store that you can test with dummy data at the same time.

You'll need to load a dump of your production data into your old version
instance. You'll also want a copy of the product images from your
`public/spree` directory so you can see them when you run the new store
with production data (this will be later, but you should get the folder
now). This stuff is in my .gitignore so it has to be copied manually.

-   Create the schema on the new machine

{% highlight sql %}
    mysql -uroot
    create schema spree_dibs_upgrade;
    exit
{% endhighlight %}

-   On the production machine, `mysqldump -u[user] -p spree > sdp.sql`

-   `scp` that over to this development vm

-   `scp` the `public/spree` folder

-   You can copy this into both the new version store as well as the
    upgrade copy of the old version

-   Load it with `mysql -uroot spree_dibs_upgrade < sdp.sql`

Keep this sql file around. We'll need it if we run into problems with
the db upgrade and have to start over.

Test the instance with `bundle exec rails s`.

Upgrade ruby
------------

I've done a post on [upgrading ruby] to discuss this topic.

Create the new Spree instance
-----------------------------

Create a new Spree instance according to the [Spree Edge Getting Started
Guide]. I've also created a (very rough) [blog post] on how I did this
for Spree 1.2. You can find the files I reference from my Spree 1.1
instance on [github]. **Don't drop the schemas in your database without
having a backup!!**

The guides sometimes lag in terms of Rails versions, especially when
Rails versions quickly due to, say, security issues. You shouldn't
always use the Rails version in the instructions if it's not the latest
release supported by Spree. You'll see announcements in the Spree blog
when they update to a newer version of Rails, while the guide still says
the old version.

The best way to determine what versions should be in the Gemfile is to
check the blog for the latest Rails version supported by Spree. Then
install that version of Rails and create a new instance with
`rails new spree_dibs -d mysql`. Look at the Gemfile created by the new
instance and copy all of the gem versions to your existing instance's
Gemfile.

-   `gem install rails -v 3.2.11` (you want a version supported by Spree
    here)

{% highlight bash %}
    gem install spree
    cd ~/vagrant
    rails new spree_dibs -d mysql
    # in this case, 1.3
    mv spree_dibs spree_dibs_[major].[minor]
    cd spree_dibs_[major].[minor]
{% endhighlight %}

-   Copy the `.gitignore` from the last store instance

{% highlight bash %}
    cp config/database.yml config/database_original.yml
{% endhighlight %}

-   The `database.yml` from the rails default install already has the
    proper configuration to talk to our db, spree\_dibs\_development,
    we're just copying it where git will save a copy of this default
    configuration since `database.yml` is ignored in my .gitignore to
    protect me from accidentally checking in a password in plaintext

-   Edit `Gemfile` and uncomment the
    `gem 'therubyracer', :platforms =>   :ruby` line

{% highlight bash %}
    mysql -uroot
    create schema spree_dibs_development;
    create schema spree_dibs_test;
    create schema spree_dibs_production;
    git init
    git add .
    git commit -m "Initial commit"
    spree install
{% endhighlight %}

-   Install default gateways: yes

-   Install default authentication: yes

-   Run migrations: yes

-   Load seed data: yes

-   Load sample data: yes

-   If bundle fails because of "encryptable", add
    `gem 'devise-encryptable` at the *end* of the file (after the stuff
    that the install added) and run `spree install` with all yeses again

-   Create a default admin user with the credentials you want

-   `bundle exec rails s` to test

You can now examine the store with a browser on your local machine by
pointing it at http://localhost:3000/. If everything is good, take the
opportunity to do a git commit.

Update Spree
------------

Edit the Gemfile and change the Spree line:

-   `gem 'spree', github: 'spree/spree', branch: '1-3-stable'`
-   `bundle update`
-   Test with `bundle exec rails s` again

Add the extensions
------------------

I use a variety of extensions. Not all of them get upgraded to be
compatible with new Spree versions immediately (or at all), so I try to
minimize the number of extensions I rely on.

To add the extensions, I look at the installation instructions and
compatibility for each one, only using ones I know have support for the
latest Spree version. I add them one at a time and test their
functionality. I won't go into the specific directions here, but you get
the picture.

Note that if you are upgrading an existing store instance rather than
installing a new one, you can get hung up if you remove extensions which
have modified your assets files. Check your commit where you originally
added the extension to see what files were modified.

Add the app customizations
--------------------------

This can be the toughest part of the upgrade and the one that tempts you
to skip this whole approach and just upgrade the store you have rather
than build one from scratch.

I look at it as an opportunity to tame the wild history of my repository
into something more sane and logical. Of course, that also means it's an
opportunity to screw it up as well, since you may end up accidentally
trimming out some details you didn't mean to, or unintentionally
introducing some bad changes. I look at this as worthwhile because the
end result is a system that helps you avoid those same mistakes when
you're working on it live, and one where you can see which changes were
meant to be made (or removed) as a unit.

It also gives you a chance to revise your history by making an entirely
new repository. This means you can rebase to your heart's content
without risking your existing history (or anyone who's forked your
repo). Rebase is a powerful tool that plays an integral part of this
grooming.

Here's my approach:

-   Clone the old store repo into a separate directory

-   You will *not* be pushing changes back from this repo!

-   Look at your early commits and visit the current revision of each

-   Use github's blame view to see where these files have had
    modifications related to the original commit

-   Compile a list of commits which trace their roots to those first,
    important commits

-   Use `git rebase -i` to rebase these later modifications back into
    the original commit

-   Usually this is a `fixup` or `squash`

-   You can use `edit` to separate a commingled commit into separate
    commits

-   Examine the rest of the commits to determine whether they are
    maintenance (can be discarded) or are new functionality (get their
    own, single commit)

-   Use `git rebase -i [commit prior to the one you're interested in]`
    to discard maintenance commits and consolidate new functionality
    into logical units

-   During this consolidation, make sure your commit messages reflect
    the the changes you've incorporated

-   Use `git format-patch [commit where you installed spree]` to export
    all of the commits as patches and copy to the new repo

-   Specify the commit that has the spree install in your old instance
    so that it's everything from, but not including, that patch which
    gets exported

-   You are done with this repo now but should hold onto it until you
    have successfully applied the patches

-   Go to the new repo and apply the patches individually by name using
    `git am --reject [patch]`

-   The commit message and metadata from the patch are imported, so you
    don't need to worry about messages

-   This allows partial application and stores rejected hunks in .rej
    files

-   To finish a partial application, fix the files that have rejects,
    `git add` them, then run `git am --continue`

-   When `Gemfile.lock` has a problem, you can often resolve it with
    `bundle install` if necessary, it completely rewrites the file in my
    experience

-   You can check what's in the patch with `git apply --stat [patch]`

-   You can do a dry run with `git apply --check [patch]`

-   If you get in too deep, you can abort with `git am --abort`

-   I haven't tried the `-i` flag to `git am`, but that may allow you to
    handle each patch individually and test without needing to name each
    one explicitly, I'm not sure

-   After each patch, verify the store and the desired changes with
    `bundle install` and `bundle exec rails s`

-   If necessary, for example with new extensions installed, run
    `bundle exec db:migrate`

-   When you migrate the capistrano settings, take the opportunity to
    switch the github url for the store to the new repo

If at any point in this process you feel that something needs to be
reorganized, I would make a note, finish applying the patches, then use
interactive rebase to revisit your changes. It's hard to bail out of a
history rewrite-gone-bad while your changes are in patchfiles, but it's
easier to do when they are in the repo and you can just abort or reset
back to an old branch.

Once you are done adding your patches, you're really done with the
temporary clone of your old version from which you exported your
patches. It's best to delete it at this point so you don't accidentally
push your rewritten history at some point.

Upgrade the old store instance
------------------------------

This is really just so you can upgrade the database schema, which is the
only missing item from the old store at this point.

We tested the working version of the old store earlier in the process,
so now we go back there and follow the standard, basic process of
upgrading a store.

We're doing this as a dry run for the real thing, so we want a
relatively recent copy of the production data sitting in our db. If
we've followed the instructions so far, that should already be the case.
If ever we screw up during this process, we can just roll back the
changes to the last commit and reload the sql dump, so keep that sql
file around.

The routine upgrade process is at the top of this post, so you'll just
need to make sure you're doing anything outlined by the Spree release
notes and blog announcements, as well as upgrading the gems, bundling
the gems, installing and running the migrations and rebuilding the
assets.

Once the store is upgraded, test that this upgraded instance is working
as expected with `bundle exec rails s`.

If you have problems and need to start over, drop and recreate the
schema for `spree_dibs_upgrade`, reload the data and revert the code to
the head state with `git checkout -- .` and `git clean -df` (be careful
with these commands, they aren't reversible). This puts the code and the
db back to the production state we copied it from.

Migrate the upgraded data to the new store
------------------------------------------

Now that the data has been migrated, we can try it out in the new store.

First you have to clear out the existing database for the new store. The
command `bundle exec rake db:reset` is almost what we want, but we don't
want to seed the database, which is the last step in that command (see
[this post] on the various rake db commands).

The quickest way is to drop and create the schema, then reload it from
schema.rb:

{% highlight bash %}
    mysql -uroot
    drop schema spree_dibs_development;
    create schema spree_dibs_development;
    exit
    bundle exec rake db:schema:load
{% endhighlight %}

You could do it all with rake commands, but they're a lot slower because
they load rails from scratch every time.

Now you've got a clean schema with no data, so you can load in the
upgraded database.

-   `mysqldump -uroot -ct spree_dibs_upgrade > sdu.sql`

-   The `-ct` options dump the data without the table creation
    statements and with column names on the inserts

-   This makes it so the current db schema is untouched and makes it not
    fail if there's any difference in the number or order of columns

-   `mysql -uroot spree_dibs_development < sdu.sql`

If you run into problems here, you'll have to figure them out manually.
Since your data will only be partly imported when it fails, you won't be
able to import the dump file again until you empty the database once
more, or else you'll get duplicate data errors.

One issue I've encountered is tables orphaned by the upgrade. The import
fails because there is no such table in the new database. The solution
is to cut the orphaned table out of the dump file. Usually this is
harmless.

If you have product images that aren't in your new store's
`public/spree` folder, copy them there now.

Verify that the store works with your production data with
`bundle exec rails s`. If everything's fine, then you're ready to do the
deployment.

Deploy the application
----------------------

In order to deploy, you need to protect the real database from changing
while you are migrating the data. That means you'll need to cut off
access to the store from everyone but you. I use a filter on my proxy to
allow myself and no one else to see the store, while everyone else gets
a maintenance page telling them when the store will be back up and how
to get their order taken by phone.

Before you do this, however, you'll want to prep the upgrade instance
(the old version of the store) on your development machine. Drop and
recreate the spree\_dibs\_upgrade schema, then use git checkout and git
clean to revert your files to the pre-upgrade state. Note that you don't
need to do a rake db:schema:load since the regular mysqldump will build
the schema for you.

Once the upgrade instance is ready, put up your maintenance page (check
it from an outside machine to make sure), then go to the production
machine, dump the database and scp it to development. Import it and run
the store once to make sure everything looks kosher.

Perform the upgrade again, remembering to run all migrations. Run the
store again on the upgraded db to verify.

Dump the db with the `-ct` options. Drop and recreate the new store's
schema, run `bundle exec rake db:schema:load`, then load it into your
new store. Run the new store to verify.

Finally, dump the new database with the regular mysqldump command (no
`-ct`) and scp it back to your production machine. Drop and create the
production schema (keep your backup handy though!) and import the new
db.

On the production machine, delete the `/data/spree/shared/cached-copy`
directory. This is where the git repo is stored there, and we need it to
change to the new repo. This tells capistrano to re-clone it from the
new git repo when you deploy.

Still on the production machine, go to the `/data/spree/shared/log`
directory and run `tail -f unicorn.stderror.log`. You'll want to watch
for any problems which occur when you run the deploy.

Finally, on your development machine, run `cap deploy` and cross your
fingers. If all goes well, you've finished your upgrade. Test the store
from your machine, then take down the maintenance page and log off the
production machine. You're done.

Wasn't that easy! ;) Congratulations. Go get some ice cream and keep an
eye on your email.

  [Spree Commerce]: http://spreecommerce.com/
  [Ruby on Rails]: http://rubyonrails.org/
  [Spree blog]: http://spreecommerce.com/blog/tag/release
  [Google group]: https://groups.google.com/forum/#!forum/spree-user
  [Vagrant]: http://www.vagrantup.com/
  [separate post]: {% post_url 2013-01-25-cloning-my-spree-instance-and-getting-it-running-under-vagrant %}
  [upgrading ruby]: {% post_url 2013-01-25-upgrading-ruby-beneath-spree %}
  [Spree Edge Getting Started Guide]: http://edgeguides.spreecommerce.com/getting_started.html
  [blog post]: {% post_url 2012-11-28-install-and-configure-spree-commerce-1-2 %}
  [github]: http://github.com/lilleyt/spree_dibs_1.1
  [this post]: http://itiansrock.blogspot.com/2012/05/difference-between-rake-dbmigrate.html
