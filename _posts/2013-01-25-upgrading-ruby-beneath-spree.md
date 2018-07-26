---
layout: post
title:  "Upgrading ruby beneath Spree"
date:   2013-01-25 00:00:00 +0000
categories:
  - spree
  - ruby
---

Ruby can be tricky to upgrade. WhenI went from ruby-1.9.3-p192 to
ruby-1.9.3-p327, my development Spree store stopped working because of
the debugger gem. After some research, I found that I had to run the
command `gem pristine debugger-linecache` to get it working after the
upgrade.

After upgrading from ruby-1.9.3-p327 to ruby-1.9.3-p362, I started
getting segfaults when trying to run Spree. As it turns out, it really
was a ruby bug and so I downgraded from p362 back to p327 and waited for
the next version.

Now that p374 is out and claims to fix the segfaults, I wanted to give
it a try. Upgrading was no easy feat this time either, in fact, it was
the most complicated yet.

I tried upgrading through rvm with the
`rvm upgrade ruby-1.9.3-p327 ruby-1.9.3-p374` command (this is on Ubuntu
12.04.1). That failed with a message saying to read the log, which told
me there was no checksum available for the ruby download, but I could
force it anyway.

Rather than do that, I did some quick research and decided to update rvm
with `rvm get latest`. This worked, but I did an extra `rvm reload`
anyway just to be sure. Unfortunately, I forgot to do the reload in my
other open shell window as well, so it gently reminded me to do so when
I tried using it. Not only that, even after rvm had been reloaded I had
trouble with gems being found after the ruby upgrade. I had to reload
rvm once more after the ruby upgrade completed for bundler to work.

After doing the update, rvm was then able to upgrade ruby to p374.
However the gemset pristine portion of the upgrade failed due to not
being able to recompile some of the gems. I believe this is caused by
the error I was able to fix next.

I then did a `bundle install` and tried to run the store, but got the
error `cannot load such file -- ruby_debug.so`. After more gnashing of
teeth, I found this could be fixed by `bundle update debugger`. Rather
than that however, it probably makes more sense to run `bundle update`
by itself after upgrading ruby since that will bring all gems
up-to-date. Although I try to avoid making such a major shakeup to the
gems the store is relying on, when you're shifting the ruby version
underneath it all, it probably makes sense to give them all a chance to
rebuild against it.

That wasn't everything though. Once I tried to run the store again, I
got the error `cannot load such file -- trace_nums`. I'd dealt with this
one before, however, when I upgraded to p327, so I knew how to solve it.
`gem pristine debugger-linecache` did the trick. After that, the store
ran just dandy! Ugh.

So the routine is basically:

{% highlight bash %}
# remember to "rvm reload" all windows
rvm get latest
rvm upgrade [old version] [new version]
rvm reload
bundle update
gem pristine debugger-linecache
{% endhighlight %}
