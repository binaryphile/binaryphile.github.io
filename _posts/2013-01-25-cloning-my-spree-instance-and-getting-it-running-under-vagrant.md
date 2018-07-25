---
layout: post
title:  "Cloning my Spree instance and getting it running under Vagrant"
date:   2013-01-25 00:00:00 +0000
categories:
  - spree
  - vagrant
---

These are my personal notes on how to get my Spree instance running
under Vagrant.  You may find them helpful too, and in fact, you can
actually clone and run my store (minus the all-important store database,
but you can do a `bundle exec rake db:bootstrap` to load the sample
data).

Note my store is configured to use mysql.  The platform I run this on is
Ubuntu 12.04.1 for development, which closely matches my production
environment.  I highly recommend running your development in a vm that
matches your production environment so as not to be caught flat-footed
at the moment of deployment because you were unaware of a platform
incompatibility.  Not only that, cheap vms serve as the cleanest dev
environments and save you from gem cache pollution without needing to
worry about rvm (even though I still use rvm for ruby upgrades).

- Make a new folder with the instance name
- Go to command line in the folder and `vagrant init`
- Copy `.vagrant` as a backup
- Edit the `Vagrantfile`
    - use `precise32spree` as the base
    - map port 3000 to 3000 on localhost
    - vm already has all the prereqs installed and a copy of the db
- Make sure other vagrant vms aren't running and `vagrant up`
- Log onto the new vm and copy ssh key in
    - Change authorized to my key
    - Add private key (with passphrase)
- _Change the account password_
- Run my sync alias `sin` to copy `/vagrant` to `~/vagrant` for performance
  reasons
- `cd vagrant`
- `git clone git@github.com:lilleyt/spree_dibs_[major].[minor]`
- `git clone git@github.com:lilleyt/spree_flexi_variants`
- `git clone git@github.com:lilleyt/spree_dibs_referral`
- `git clone git@github.com:lilleyt/spree_email_to_friend`
- `git clone git@github.com:lilleyt/spree_print_invoice`
- Visit each directory, check out the current commit listed in
  `spree_dibs_[major].[minor]/Gemfile.lock`
    - If the revision isn't in the repo, add the upstream, `fetch --all` and
    try again
- `cd spree_dibs_[major].[minor]`
- `cp config/database.yml.original config/database.yml`
- `bundle install --without production`
- Either copy in your production db (mysqldump, create schema and mysql) or
  `bundle exec rake db:bootstrap`
    - If you bring in your production db, copy the `public/spree` folder from
    production or another instance
- `bundle exec rake assets:precompile:nondigest`
- Test with `bundle exec rails s`
