---
layout: post
title: "Getting Bash"
date: 2020-07-06 22:00 UTC
categories: [ bash ]
---

If you're interested, start the series with [part 1].

If you're on linux, you're in luck.  You've already got the latest bash
for your release on your system.  If you aren't using it already, you
just need to [change your default shell to bash]: run `chsh -s
/bin/bash`.

If you're on macos, it's a bit more involved.  The system bash is an
unconscionably old version, and the newest macos releases default to
zsh.  You'll need [homebrew] installed first to install the latest bash.
Open a terminal and follow the directions on the homebrew site.

Once homebrew is installed, install bash with `brew install bash`.

Then, make bash your default shell.  First you'll need to add it to
**/etc/shells**: run `sudo -e /etc/shells`.  Add the following line to
the end of the file and save:

    /usr/local/bin/bash

Next, run `chsh -s /usr/local/bin/bash`.  Every new terminal window will
use the latest bash.  Close your existing window, open a new one and run
`echo $BASH_VERSION` to see what version you are on now.  It should be a
version of bash 5.

  [part 1]: {% post_url 2020-07-02-how-i-bash-a-new-series %}
  [change your default shell to bash]: https://linux.die.net/man/1/chsh
  [homebrew]: https://brew.sh/
