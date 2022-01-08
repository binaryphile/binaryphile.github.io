---
layout: post
title: "Bash Environment Variables"
date: 2022-01-08 12:00 UTC
categories: [ bash ]
---

If you're interested, start the series with [part 1].

In the [last part], we learned about the broad scope of bash
initialization files.

This time let's pick a specific thing to customize, environment
variables, and see how that's done.

In particular, let's use a real-life example.  Let's add a directory to
the PATH environment variable.

If you aren't familiar with environment variables, the brief explanation
is that they are a method for the shell to pass information (strings, to
be specific) to processes that you tell it to run.  An environment
variable is a shell variable with an additional bit of metadata which
tells the operating system to copy the variable into the subprocess of a
command you run.

PATH is the most famous of the environment variables.  On a Linux
system, PATH is a colon-separated list of directories.  The directories
are locations that are searched one-at-a-time to find an executable
program when you don't supply that program's location on the command
line.

Let's make a directory that will allow us to put programs there when we
want them to appear on the path.  By convention, user home directories
usually put them in `~/bin` (ok) or `~/.local/bin` (better).  Let's make
the directory, then add it to PATH in an initialization file.

As a note, when I run commands on the command line, I'll use `>` to
denote the prompt.

Open a command prompt and run `mkdir`:

```bash
> mkdir -p ~/.local/bin
```

The `-p` option allows us to make both the `.local` as well as the `bin`
directory in one go.  `~` is a special shell character which denotes our
home directory.  It's expanded to our actual home path prior to the
command being executed.

Now let's add the directory to our path.  What we want to do is append
the directory to the existing value of PATH, so we don't lose the
functionality already given by PATH.  Most of the time, you see this
done by expanding the existing PATH in a new PATH assignment:

```bash
export PATH=$PATH:$HOME/.local/bin
```

That command does three things:

-   expands the existing PATH as `$PATH`
-   appends `$HOME/.local/bin` with a colon `:`
-   `export`s the variable to the environment

There's definitely some redundancy in there that we can simplify out.  I
prefer the following more succinct version:

```bash
PATH+=:$HOME/.local/bin
```

-   I've dropped `export`.  While PATH is not exported to the
    environment when bash starts up without any configuration, by
    convention, it is exported to the environment in the system's bash
    initialization files.  Once exported, an environment variable stays
    exported for good, so you don't have to re-export it.  There may be
    some esoteric edge case where the system's files aren't run while
    ours is, but I haven't encountered it and I like simple until
    there's a demonstrated need for complicated.

-   I'm using the string append operator `+=` rather than `=`.  This
    still assigns to the variable, but it adds the right-hand side to
    the end of the existing variable value.  No need for expansion of
    `$PATH`.  You do need, however, to remember to include the colon
    separator yourself.  It's the first character of the right-hand
    side, not a part of the `+=` operator itself.

Note that for security you typically want to add to the end of your PATH
rather than the beginning, so you don't accidentally replace a system
command with your own.  The directories are searched in order until the
first matching program is found, so earlier directories in PATH
supersede later ones.

You may also have noticed that I didn't use `~` for the home directory
as I do on the command line, instead using `$HOME`.  As a rule of thumb,
I always use `$HOME` in scripts because it is more robust than `~`.
Tilde only expands properly if it is at the start of a word, or in an
assignment if it is directly after the `=` or a `:` separator.  That
means that using it in command-line options sometimes fails.  `$HOME` is
a simple habit which always works in scripts.  Interactively on the
command-line, I allow myself to use `~` for succinctness.

So we're almost done here.  The last thing to do is determine *where* to
add this line.  There's generally four options:

-   ~/.bash_profile
-   ~/.profile
-   ~/.bash_login
-   ~/.bashrc (not really an option, but you might think so)

As we saw in the diagram from the [last part], all four of these files
are normally somewhere in the mix of shell startup.  It gets confusing
though.  Without going into extraordinary detail, the usual place is
.bash_profile.

The reason we don't want to use .bash_login is that .bash_profile is
preferred and .bash_login won't be loaded if .bash_profile is present.

.profile and .bash_profile play mostly the same role.  .profile is
relied upon by the desktop login system on Ubuntu, so you may already
have that in your directory (other Linuxes may do things differently).
If so, use it.  Ubuntu doesn't open login shells, so .profile is the
general solution in that case.  However, if not, I stick with
.bash_profile, so I'll use that as my reference point for this article
(I'm on MacOS).

You'll see .bashrc mistakenly recommended as a place to set or modify
environment variables.  The problem with .bashrc for environment
variables is that it's frequently loaded then reloaded.  Whenever a new
interactive shell is started, .bashrc is loaded.  If it is the first
time that the shell is being loaded, an environment variable set in
.bashrc will be set correctly.  However, the process may not end there.
If a command ends up spawning another interactive shell, .bashrc will be
loaded again.  The environment variable will already exist from the
ancestor shell, when .bashrc sets/changes it again.  If the variable is
being set in .bashrc, any intervening change to the environment variable
will then be overwritten.  Alternatively if the variable is being
modified in .bashrc, the change will occur again.  This can, for
example, extend PATH with multiple copies of the directory.

For these reasons, .bash_profile is the right place to modify
environment variables like PATH.  It is only loaded once by the original
login shell, the ultimate parent.  Child shells will only run .bashrc,
not .bash_profile again.

If you already have a .bash_profile, we can add our line to it.  The
best location is at the end of the file.  That way, if .bash_profile
loads any other files, putting our changes at the end will make sure
that they happen after everything else has made its PATH changes.

The alternative is to add it elsewhere there is a PATH modification
already in the file.  That's fine as well, but add our directory at the
end of the assignment.

Before we make this change, let's just inspect PATH to make sure we
don't already have `~/.local/bin` there (some systems add it already):

```bash
> echo $PATH
```

No?  Great.  Otherwise, let's test our modification but back it out
later so as not to duplicate the path.

Open ~/.bash_profile and add the line:

```bash
PATH+=:$HOME/.local/bin
```

Ok, let's test the change.  Unfortunately, there's one more tricky bit.
If you're on MacOS, then opening a new terminal window will typically
run a login shell, meaning that it will see the change and you can run
`echo $PATH` to verify our change.  (that's good, that's not the tricky
bit)

On Ubuntu however, the desktop system typically runs ~/.profile.
Opening a new terminal shell will run an interactive shell (not login)
and only .bashrc will be run.  In that case, the change will only happen
if you log off and back on.  So do that if necessary.

Now, open a new terminal and `echo $PATH`.  Is our directory there?
Great!  Otherwise you'll need to do some snooping.  Start by sourcing
our file explicitly: `source ~/.bash_profile` and try again.  If that
works but not when you open a new window, then use `shopt login_shell`
to see whether you are in a login shell or not.  If not, reboot the
machine and try again.

Well, that was quite involved, wasn't it?  It gets easier.  At least the
actual change was easy and we won't need to go over the initialization
file options again.

See the [next part] for application initialization.

  [part 1]: {% post_url 2020-07-02-how-i-bash-a-new-series %}
  [last part]: {% post_url 2020-07-12-customizing-bash %}
