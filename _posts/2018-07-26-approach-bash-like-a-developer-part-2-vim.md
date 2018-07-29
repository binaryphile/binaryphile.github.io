---
layout: post
title:  "Approach Bash Like a Developer - Part 2 - Vim"
date:   2018-07-26 00:00:00 +0000
categories:
  - bash
  - vim
---

This is part two of a series on how to approach bash programming in a
way that's safer and more structured than your basic script.

Editor's Choice
---------------

Before getting into coding, I want to recommend a good editor. A
developer's choice of an editor is like a chef's choice of knives; a
wise choice will serve a lifetime and make difficult tasks seem
effortless. Vim is one such wise choice for slicing, dicing and
julienning code.

That's not to say there aren't other good editors out there. For
lightweight, functional text editors, I can recommend some good ones:

-   Linux - [Geany]

-   Windows - [Programmer's Notepad]

-   Mac - Sorry, there aren't any great lightweight, free Mac editors of
    which I'm aware - try [Atom] for two out of three

Vigor and Vim
-------------

Ok, so you're sold on vim already. Vim works great for bash scripting
out-of-the-box. So what more is there to say?

See my [vim configuration repository] for full details, but here are a
couple tips (and a tip of the cap to mutewinter's Vim Configuration of
Champions, from which most of these come):

-   auto-delimiters - having matching parentheses, braces and quotes
    auto-added can be really nice. Try [delimitMate].

-   auto statement endings - like the above, but automatically puts
    in the closing word (e.g. *done* or *fi*) for constructs such as
    *for* and *if* with [vim-endwise]

-   comments - comment and uncomment several lines at a stroke with
    [tcomment]

-   tab completion - the simplest is [VimCompletesMe]

-   indent guides - 'nuf said - [vim-indent-guides]

Once you're into the advanced stuff:

-   pair-wise manipulation of delimiters - [vim-surround] takes the
    tedium out of editing pairs of delimiters, especially for a language
    as quotation-heavy as bash is

-   exuberant ctags - if you like to find function definitions easily
    across multiple files, then [vim-easytags] is your friend

Color by Numbers
----------------

Line numbers. Use them.  Navigate vertically with *\<line number\>G* and
reorient the page with *z\<Enter\>*.

*.vimrc:*

{% highlight viml %}
set number
{% endhighlight %}

Put It On My Tab
----------------

Use smart tabs for two-space indentation.

*.vimrc:*

{% highlight viml %}
set tabstop=2
set shiftwidth=2
set shiftround
set cindent
set expandtab
{% endhighlight %}

To indent and de-indent a single line or selected blocks of code, use
the `<<` and `>>` commands.

The Show Must Go On
-------------------

Show matching delimiters and special whitespace.

*.vimrc:*

{% highlight viml %}
set showmatch   " Show matching brackets.
set matchtime=2 " How many tenths of a second to blink
" Show invisible characters
set list
" Reset the listchars
set listchars=""
" make tabs visible
set listchars=tab:▸▸
" show trailing spaces as dots
set listchars+=trail:•
" The character to show in the last column when wrap is off and the line
" continues beyond the right of the screen
set listchars+=extends:>
" The character to show in the last column when wrap is off and the line
" continues beyond the right of the screen
set listchars+=precedes:<
{% endhighlight %}

When I Say "Shell", You Say "Bash"
----------------------------------

Hint to vim that when you say shell, you mean bash syntax.

*.vimrc:*

{% highlight viml %}
let g:is_bash = 1
{% endhighlight %}

Continue with [part 3] - the start.

  [Geany]:                        https://www.geany.org/
  [Programmer's Notepad]:         http://www.pnotepad.org/
  [Atom]:                         https://atom.io/
  [vim configuration repository]: https://github.com/binaryphile/dot_vim
  [jellybeans]:                   https://github.com/nanotech/jellybeans.vim
  [quick-scope]:                  https://github.com/unblevable/quick-scope
  [delimitMate]:                  https://github.com/Raimondi/delimitMate
  [vim-endwise]:                  https://github.com/tpope/vim-endwise
  [shellcheck]:                   https://www.shellcheck.net/
  [syntastic]:                    https://github.com/vim-syntastic/syntastic
  [tcomment]:                     https://github.com/tomtom/tcomment_vim
  [VimCompletesMe]:               https://github.com/ajh17/VimCompletesMe
  [vim-indent-guides]:            https://github.com/nathanaelkane/vim-indent-guides
  [vim-surround]:                 https://github.com/tpope/vim-surround
  [vim-easytags]:                 https://github.com/xolox/vim-easytags
  [idempotent]:                   https://en.wikipedia.org/wiki/Idempotence#Computer_science_meaning
  [part 3]:                       {% post_url 2018-07-26-approach-bash-like-a-developer-part-3-the-start %}
