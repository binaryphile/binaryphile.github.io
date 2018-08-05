---
layout: post
title:  "Approach Bash Like a Developer - Part 8 - Utility Library"
date:   2018-08-04 00:00:00 +0000
categories: bash
---

This is part eight of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we described how to source a library without depending on
PATH. This time we'll look at putting our utility functions in a library
and sourcing them from our script.

In the Library, With the Lead Pipe
----------------------------------

Let's extract out our *sourced* function into a utility library.  First
we'll need a `lib` directory:

    mkdir lib

*lib/util.bash:*

    sourced () {
      [[ ${FUNCNAME[1]} == source ]]
    }

Note that there's no shebang for a library file since it's never run as
a command.

*bin/hello_world:*

    #!/usr/bin/env bash

    source "$(dirname -- "$(readlink --canonicalize -- "$BASH_SOURCE")")"/../lib/util.bash

    main () {
      hello_world
    }

    hello_world () {
      echo "hello, world!"
    }

    sourced && return

    main "$@"

Continue with [part 9]

  [part 1]:     {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro    %}
  [Last time]:  {% post_url 2018-08-04-approach-bash-like-a-developer-part-7-sourcing %}
