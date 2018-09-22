---
layout: post
title:  "Approach Bash Like a Developer - Part 18 - Word Splitting"
date:   2018-08-31 00:00:00 +0000
categories: bash
---

This is part eighteen of a series on how to approach bash programming in
a way that's safer and more structured than your basic script.

See [part 1] if you want to catch the series from the start.

[Last time], we went over all of the steps in bash command processing.
This time, let's talk about one of the steps in particular, word
splitting of expansions.

Breaking Up Is Hard To Do
-------------------------

Word splitting is a feature of the shell which applies after certain
expansions.  Such expansions include variable expansion, command
substitution and process substitution (and technically arithmetic
expansion as well, although it's unclear to me how that could ever
result in multiple words).

Any of these expansions can result in text with whitespace.  Bash
decides that this text should not be taken together as one entity, but
rather should be split into separate words before invoking the resulting
command.

For example, consider the assignment *myfiles="file1.txt file2.txt"*.
The following command copies both files into another directory:

{% highlight bash %}
# note that this cannot work with filenames with spaces!
cp $myfiles target_dir/
{% endhighlight %}

After expanding *myfiles* into a string, bash takes it upon itself to
split the resulting string into the two words based on the whitespace
between them, resulting in *file1.txt* and *file2.txt*.

If it hadn't done so, then the *cp* command would try to find a single
file with the name "file1.txt file2.txt" and copy it instead.

That's pretty much the idea behind word splitting.  In some cases, it
can make it easy to store multiple arguments to a command in a single
string since they'll be split back into individual arguments before the
command is invoked.  It can also be used to iterate in a loop such as
this one, which accomplishes the same thing as the command above:

{% highlight bash %}
for file in $myfiles; do
  # still no spaces allowed in filenames!
  cp $file target_dir/
done
{% endhighlight %}

Here *myfiles* is working like an array would in other languages,
allowing *file* to iterate through its values.

Really, though, word splitting is only of use if you choose to rely on
it, and there's no need to do so.  Bash has had arrays for quite some
time now, and they not only supersede whitespace-based lists, they are
better at what they do.  There's almost no occasion to use a poor-man's
array.

Here's how the same loop would work with an actual array.  This one
works with spaces in filenames:

{% highlight bash %}
myfiles=( file1.txt "My Documents/file2.txt" )
for file in "${myfiles[@]}"; do
  cp "$file" target_dir/
done
{% endhighlight %}

It may be tempting to write the earlier code
since it looks a bit cleaner and is easier to write, since you aren't
thinking about quotation marks, brackets or @ symbols.

Don't be fooled, though.  First of all, it simply doesn't work for valid
inputs with spaces.  That's not an edge case.

Second, the quotation marks are *because* of the automatic word
splitting.  Turn it off and the need for them goes away.  In fact, all
of our code will look better.

If you've been following my code so far, you'll have noticed fairly
liberal usage of quotation marks already.  In fact, I've used them on
*every expansion* (with a couple exceptions for statements which don't
do word splitting).

The reason for all the quotes is word splitting.  There's a big problem
with it.  It simply shouldn't be done automatically.

You see, wherever there *might* be a space in an variable expansion, you
have to disable word splitting manually, or else you won't get be
getting the value stored in the variable.  You'll be getting two or
three or more things instead.

That's what the double-quotes do, they disable word splitting on the
expansion result.

Take pathnames with spaces as an example again.  If you want to store
such values in a variable, you can't use that expansion without
disabling word splitting with double quotes.  In fact, it's
unpredictable enough that the standard practice is to double-quote
*every* expansion, all the time.  It's a waste of time and a ton of
visual noise in your code.

Most people who write scripts either don't know or don't care,
preferring not to litter their code with quotes.  That's understandable.
But it introduces a class of bugs which bite you in the edge case and
are pervasive throughout your code.  All because of a feature you're
probably not even using anyway.

So what to do?  Turn it off, and if you happen to need it, toggle it on
and back off again.  Trust me, you won't need it much.

Continue with [part 19] - disabling word splitting

  [part 1]:       {% post_url 2018-07-26-approach-bash-like-a-developer-part-1-intro                      %}
  [Last time]:    {% post_url 2018-08-25-approach-bash-like-a-developer-part-17-command-processing        %}
  [part 19]:      {% post_url 2018-09-01-approach-bash-like-a-developer-part-19-disabling-word-splitting  %}
