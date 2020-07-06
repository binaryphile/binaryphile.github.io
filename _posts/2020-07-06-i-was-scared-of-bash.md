---
layout: post
title: "I Was Scared Of Bash"
date: 2020-07-06 12:00 UTC
categories: [ bash ]
---

If you're interested, start the series with [part 1].

I admit it. I was scared of bash. It seemed so confusing. Whoever
thought `$` was a good character for a command prompt? Right from the
get-go, bash felt strange and foreign.

I was used to the familiar `C:\>`. I was even used to the improved C
shell, [tcsh], although I don't remember its prompt character (Wikipedia
shows `%`, but I think our system had it modified to `>`).

It just seemed like bash intentionally had been made for an older time,
a relic which preexisted any kind of ergonomics or user experience
concerns. A cursory examination of the home directory initialization
files did little to change that impression. And documentation for bash,
such as the man page, was more dense than Amazonian rainforest.

Nevertheless, I ventured in a bit, writing the *de rigeur* `ls` aliases
and learning the names of **\~/.profile**, **\~/.bash\_profile** and
**\~/.bashrc**, not really understanding the difference between them
all.

When I had my own system, I finally decided to learn something about the
shell. But if I was going to invest myself in a shell, I figured I
should learn something that would be more powerful and friendlier than
bash (I learned later that was probably a mistake, at least for me).

I picked up **zsh**, since that seemed to be what all the cool kids were
using. It helped that its primary "killer app" was a decent prompt that
showed useful things like the status of git repo directories. It used
color, and had a plugin system for initialization files and additional
functionality. It seemed like a slam dunk.

However, zsh started to lose its appeal. Yes, there was an easy, cool
prompt. But I started paying attention to those who were saying
oh-my-zsh (the plugin system) was bloated and slow. I also didn't learn
much new about how to use the shell. zsh was designed to be mostly
bash-compatible, however, that was a double-edged sword. It carried a
lot of the illegibility of bash, while only smoothing off some of the
sharp edges. At least, that's the impression I had. If I was going to
invest in learning to script in zsh, not only was I giving up
compatibility with most of the systems I work on, I was also going to
have to maintain two bodies of very similar knowledge: what bash and zsh
can do, and now the difference between them as well.

At this point, I started realizing it was going to be difficult not to
learn bash. I hadn't quite given up yet. I tried fish shell, the
*f*riendly *i*nteractive *sh*ell. I loved it. It was so well-designed,
with excellent defaults and simplified setup for those things that I
needed to customize (aliases, for example). I had to relearn the basics
since it didn't share anything with bash, but that was a strong point.
The basics had been re-imagined and made better.

But, I always would end up needing to work with systems that didn't have
fish, and I couldn't bring fish with me. In the back of my mind, I knew
that everything I learned in fish was keeping from learning the same
thing in bash, and I would never get good with precisely the systems
with which I needed to be my best.

The straw that broke the camel's back was when I wanted to start
automating tasks on production systems. Shell scripting was the best
tool for the job. I'm well-versed in Python and Ruby, having done each
professionally, but neither is as suited for gluing together
command-line utilities as bash. To top it off, fish is weak on
scripting, admittedly focusing on interactive use.

I decided that if I were to learn scripting, I would need to immerse
myself in bash, including interactively. As I've found out, bash may not
have all the bells and whistles of fish or zsh, but if you configure a
few features under the hood, it's a perfectly functional and powerful
environment. I've finished my learning curve and could switch back to
another shell, but now I have no need. Bash does everything I want, and
does it everywhere I need.

  [part 1]: {% post_url 2020-07-02-how-i-bash-a-new-series %}
  [tcsh]: https://www.tcsh.org/
