---
layout: post
title:  "Simple, semantic table layout for non-table markup"
date:   2013-04-03 00:00:00 +0000
categories: css
---

What it is
----------

A css file and markup technique for putting form fields into a regular,
columnal format that degrades gracefully without css by the use of css
2.1 table display property values.

How to get it
-------------

See [this gist]. You can see it in action at [this jsFiddle], but the
gist is better for downloading since it always gives you the latest
version while the same is not true of the jsFiddle.

How to use it
-------------

Add the css to the rest of the css for your site. When creating a form,
decide whether you'll be using lists or divs. The basic list version
looks like:

{% highlight html %}
    <form>
      <ul class="tel-tabular">
        <li> <!-- each li is a row -->
          <label>Field 1:</label><input>
          <label>Field 2:</label><input>
        </li>
        <li>
          <label>Field 3:</label><input>
          <label>Field 4:</label><input>
        </li>
      </ul>
    </form>
{% endhighlight %}

For more details, read the rest of the article.

Introduction
------------

In this article I'll show you how to use css to turn form markup into a
nice table layout. The great thing about tables is that all of the cells
in a row get sized properly to align with everything else in their
column. Forms look particularly nice this way they are usually tabular,
with labels in the first column and inputs in the second. You may even
want to have more than one field in a row, but you still want the
columns to size to the width of their widest content.

There are a number of other techniques to layout forms, and they keep
evolving. This technique has the advantages that it's truly table-based
without the table markup. You get automatic column sizing, so you don't
need to know the width of your content a priori like you do with other
techniques. This is especially handy if you simply don't know the width
of your content. For example, you may be pulling field names from a
database or you may be pulling translations for field names for
internationalization purposes. The table approach works best for these
situations.

I'll also show you how to handle some of the common exeptions to the
layout without blowing the layout as a whole. For example, you may need
to have one row in the midst of others whose cell size would be much
shorter or longer than you'd want for the others. I'll show you how to
handle those rows while still keeping the preceding and following rows
connected in the same table, so the column widths apply throughout. I'll
also show you how to put fieldsets in the flow of the form without
breaking things into separate tables.

This approach is fairly flexible in the markup it accepts. You can do
div-based forms or list-based forms, although you may have to adapt your
normal method to the structure required here. In any case, this
flexibility is designed so you can write markup which degrades
gracefully without css, so you get something that is perhaps not as
pretty, but still true to the spirit of the layout.

This technique works for current versions of Chrome, IE and Firefox,
with minor tweaking of some widths for the advanced features. I don't
know how far back you need to go before you start to lose support.
Anything that supports css 2.1 should work.

I haven't gone into any of the explanations behind the css because while
I meant to, the time consumed in developing it proved to be too much so
I'm posting what I can. I hope to come back to it and do a more detailed
explanation.

Why not html tables, floats or inline-blocks?
---------------------------------------------

The historical ways that you can create a multi-column table-like layout
is to use one of these three methods. However:

-   Html tables are frowned upon for anything other than tabular data by
    just about everyone nowadays.
-   With floats, it's difficult to get columns to match in height like
    table columns do automatically. Floats end up being column-oriented
    and I want row-oriented markup which is degrades gracefully to
    non-styled layout.
-   Inline-blocks are pretty good, but require you to know the widest
    width of a given column and set a minimum-width on all of the
    elements. If you are creating content on-the-fly, you can't know its
    width a priori. That can and will blow the layout. Where it really
    falls down are internationalized apps where you may have no idea
    what your widths are going to be.

Basic form
----------

I designed the css for either list-based or div-based forms. I'll show
list markup then explain the div version.

This example supposes that you want a four column form, one column each
for a couple label/input pairs.

The markup:

{% highlight html %}
    <form>
      <ul class="tel-tabular">
        <li> <!-- each li is a table row -->
          <label>Field 1:</label>
          <input>
          <label>Field 2:</label>
          <input>
        </li>
        <li>
          <label>Field 3:</label>
          <input>
          <label>Field 4:</label>
          <input>
        </li>
      </ul>
    </form>
{% endhighlight %}

What you get here is a two-row table with two label/input pairs per row.
If you change the content of any element, the layout will adjust and
keep everything in columns as you would expect of a table.

The css:

{% highlight css %}
    .tel-tabular > * {
      display: table-row;
    }

    .tel-tabular > * > * {
      display: table-cell;
      padding-right: 0.3em;
    }

    .tel-tabular input {
      margin-right: 1em;
    }

    label {
      text-align: right;
    }
{% endhighlight %}

I've put in some of my own preferences for display such as
right-alignment of labels, etc.

Note that you can just as easily make a 6-column layout (or any you
want) just by adding elements to each li.

Using divs instead of ul
------------------------

If you prefer divs, just substitute them for the ul and li elements like
so:

{% highlight html %}
    <form>
      <div class="tel-tabular">
        <div> <!-- each div under .tel-tabular is a table row -->
          <label>Field 1:</label>
          <input>
          <label>Field 2:</label>
          <input>
        </div>
        <div>
          <label>Field 3:</label>
          <input>
          <label>Field 4:</label>
          <input>
        </div>
      </div>
    </form>
{% endhighlight %}

In fact, you don't even need the enclosing div. You can eliminate it and
apply the tel-tabular class to the form itself.

You can use divs instead of uls for the rest of the examples in the same
way, so I won't bother showing both methods.

Overflowed cells
----------------

You can make an element that streches outside of its cell so that you
can handle unusual situations that might normally break the flow of the
table as a whole.

The markup:

{% highlight html %}
    <form>
      <ul class="tel-tabular">
        <li>
          <label>Field 1:</label>
          <input>
          <label>Field 2:</label>
          <input>
        </li>
        <li>
          <span>
            <span>
              <input type="checkbox">
              <label>A checkbox that has a long label</label>
            </span>
          </span>
        </li>
      </ul>
    </form>
{% endhighlight %}

The structure is the same as you would expect for the first row from the
first example. The second row, however, holds a checkbox and label that
will look too far spaced apart if they are put in separate cells, but
won't fit inside a single cell either.

This markup will put them in a single cell but allow them to overflow
outside the cell without affecting the rest of the table. Notice the two
spans around the items that will extend outside of their cell. They will
allow the css to do the proper formatting.

The css for it is in addition to the earlier css:

{% highlight css %}
    .tel-tabular > * > * > * {
      display: inline-block;
      width: 0;
      white-space: nowrap;
    }
{% endhighlight %}

Note that if you want to add further content to the same row, you will
have to pad the row with blank cells until you reach one that doesn't
overlap with the overflow.

You can do this with empty cells:

{% highlight html %}
    <li>
      <span>
        <span>
          <input type="checkbox">
          <label>A checkbox that has a long label</label>
        </span>
      </span>
      <span>&nbsp;</span>
      <span>&nbsp;</span>
      <label>Some more content</label>
    </li>
{% endhighlight %}

Short fields
------------

You might also want to put multiple fields in a cell where space
permits. The classic example of this is the state and zip fields in an
address.

We'll make the label for the state field be the first cell as usual.
We'll then use the overflowed cell technique to place the state input as
well as the zip label and input into the following cell. In this case,
we're not actually overflowing the cell but the technique works to
prevent each individual content item from being assigned to its own
cell.

This time we'll only need css for defining our input widths, but we'll
need new classes for that purpose.

The additional css:

{% highlight css %}
    .tel-tabular .tel-state {
      width: 2em;
      margin-left: 0.2em;
      margin-right: 0.3em;
    }

    .tel-tabular .tel-zip {
      width: 5em;
    }
{% endhighlight %}

Note that we'll also need some margins on the first input to get the
second one to line up on the right edge of the column. The rendering
tends to be browser-specific, so choose which browser you want to
optimize for and accept that it isn't going to be perfect on the others.
Or figure out a better method than this one. :)

Also note that I've included the .tel-tabular qualifier on both
selectors. You wouldn't have to do this normally, but in this case I'm
planning ahead to avoid conflicts with the css I'll be introducing in
the next section.

The markup:

{% highlight html %}
    <form>
      <ul class="tel-tabular">
        <li>
          <label>Field 1:</label>
          <input>
          <label>Field 2:</label>
          <input>
        </li>
        <li>
          <label>State:</label>
          <span>
            <span>
              <input class="tel-state">
              <label>Zip:</label>
              <input class="tel-zip">
            </span>
          </span>
        </li>
      </ul>
    </form>
{% endhighlight %}

You can still put further fields on the same line by adding them to the
same li. You can pad out blank cells with the <span> </span> method as
well.

Fieldsets
---------

Unfortunately, if you put a real fieldset in the middle of the form, it
divides the form into separate tables before and after the fieldset. I
couldn't find a way to keep this from happening, and it ruins the
gestalt of the form.

You can make separate tables look the same by assigning minimum widths,
but then we're back to the inline-block method anyway, which I didn't
want. Instead, I'll fake a fieldset by mocking it up with a div.

The markup:

{% highlight html %}
    <form>
      <ul class="tel-tabular">
        <li>
          <label>Field 1:</label>
          <input>
          <label>Field 2:</label>
          <input>
        </li>
        <li class="tel-fieldset">
          <div class="tel-legend"><div>Legend text</div></div>
          <div>
            <label>Field 3 (with filler):</label>
            <input>
            <label>Field 4:</label>
            <input>
          </div>
        </li>
        <li>
          <label>Field 5:</label>
          <input>
          <label>Field 6:</label>
          <input>
        </li>
      </ul>
    </form>
{% endhighlight %}

Here the li gets the fieldset class. It includes a legend div (with an
embedded div to give the css what it needs). The other div contains the
rows for the fields. We have to use divs for rows instead of lis at this
point, but it still degrades nicely without css. Without css, the legend
visibly marks off the fields as being separate, and they are gathered
under a single bullet.

The additional css is a bit more complicated, partly because it has to
support the capabilities of overflowed and short cells. It also has to
neutralize some properties that bleed onto it due to the use of \*
selectors in the earlier css, but it's pretty harmless and I wanted to
allow you to choose between uls and divs as you see fit, so it's worth
the bit of additional complexity.

Here it is:

{% highlight css %}
    .tel-tabular > * {
      display: table-row-group;
    }

    .tel-tabular {
      border-collapse: collapse;
    }

    .tel-fieldset {
      border: 1px solid;
    }

    .tel-fieldset > * {
      display: table-row;
      padding-right: 0;
    }

    .tel-fieldset > * > * {
      display: table-cell;
      white-space: inherit;
      padding-right: 0.3em;
      width: auto;
    }

    .tel-fieldset > * > * > * {
      display: inline-block;
      width: 0;
      white-space: nowrap;
    }

    .tel-legend {
      position: relative;
      display: block;
    }

    .tel-legend > * {
      position: absolute;
      top: -0.74em;
      left: 0.6em;
      display: block;
      background: white;
      padding: 0 0.3em;
      white-space: nowrap;
    }

    label {
      padding-bottom: 0.7em;
      padding-top: 0.6em;
    }
{% endhighlight %}

Notice that we've changed the display of .tel-tabular &gt; \* from
table-row to table-row-group. This allows us to add a level of rows
under the .tel-fieldset element that are still rows and still align with
the columns. In the css in [this gist] I just use the table-row-group
value in the first place. For this article I just wanted to show the
progression of the css as we added features.

Also notice the padding added to the label element. This is so that the
legend text doesn't cramp the lines above and below it. This is the easy
way out since I'm adding that padding to every line, not just the ones
before and after the legend. If someone can figure out an elegant way to
just pad the legend, I think that would be better. Another (ugly) method
is to add a row of empty cells before and after the fieldset with a div
full of of nbsp spans. You'll probably want to add some around the
ending div tag of the fieldset as well. It looks nice when rendered, but
not very good practice for html.

The legend has a background which has to be set in order to a color to
mask the fieldset border, so choose one that matches your page
background. It can't be transparent because the border will show.

There *are* some gotchas with these mock fieldsets which I've
encountered in practice.

The fieldset border will have a gap if there is no cell in the final
column of your row. Stub out all fieldset rows with blank <span> </span>
cells to fix this.

The top of the fieldset border also requires that the table-row-group
*before* it has all of the cells in a row. That means that if it's the
first thing in the form, you have to put in a dummy div before it which
contains the right number of nbsp spans.

Other Caveats
-------------

While automatic table layout is great, it does come with it's own set of
rules. The biggest issue I've run into is that you can't set margin on
most table elements, including rows and the table itself. Some items
with display: table-cell will let you set margin though, such as the
labels. This can be a big drawback of this method.

The other table-related caveat is that setting height of 100% doesn't
work on table cells. Explicit heights in px or ems seems to work fine,
but I'm not sure if it's just percentages or 100% in particular.

If you are used to using nested lists to define fieldset-like areas in
your forms, you will have to use divs nested inside the lists instead.
The structure of the css requires it, and I can't see a way to allow
nested lists without breaking the table flow.

Because overflowed cells are width 0, trying to use one on the right
side of a fieldset will cause it to overflow the border, so you don't
want to do this. Keep overflowed cells on the left side of your table
where they will have space from following columns to rely on. Short
fields which are attached to the widest field in the rightmost column
will similarly overflow the fieldset.

The last caveat is that you'll need to tweak the css to match the feel
of your design through the use of color, fonts, padding, etc. You may
also have to tweak the padding on labels to ensure that the legend on
fieldsets isn't overlapping the rows before and after. Since this is
likely to result in slight variations between browsers, choose which
browser you want to target and develop for that one first.

Don't forget to test your results on the browsers you care about.

Bonuses
-------

Because these are real tables, you get vertical alignment for free,
which is not true of other layout methods. I don't use it in forms but I
do use it when I do page layouts, for example.

Conclusion
----------

That's how to achieve table-based layouts with forms. Tables have the
advantage of automatically accomodating the width of their content,
which makes them ideal for laying out forms where the content width is
not necessarily known beforehand.

You can choose between div-based layout and list-based layout. The
layout degrades gracefully without css, so the form is still usable in
that case and friendly to assistive technologies.

You can designate some cells to be short or long without affecting the
width of their column through a combination of css and markup. The rest
of the table before and after keep their flow and still look like a
unified table.

The same is true of fieldsets through the use of our mock fieldsets done
in css. While you can't use real fieldsets without breaking the flow of
the table before and after, you can use the mock fieldset and it looks
close to the same.

That's it. Please drop me a comment if you find this useful!

  [this gist]: https://gist.github.com/binaryphile/5321689
  [this jsFiddle]: http://jsfiddle.net/sqDLz/9/
