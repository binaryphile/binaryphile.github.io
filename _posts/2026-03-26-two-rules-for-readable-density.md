---
layout: post
title: "Two Rules for Readable Density"
category: development
---

Most readability advice resists mechanical checking. "Use good names." "Keep
functions short." You need the whole function, maybe the whole module, to
evaluate those. These two rules you can check by reading a single line. The
examples are in Go, but the rules apply to any language with nested expressions.

## The uniform comma rule

Every comma in an expression should belong to the same argument list.

```go
result := append(append(items, extra), overflow...)
```

Two commas, but they belong to different calls. `items, extra` feed the inner
`append`. `append(items, extra)` and `overflow...` feed the outer. Your eye has
to match each comma to its call to parse this.

```go
combined := append(items, extra)
result := append(combined, overflow...)
```

Every comma on each line belongs to one call.

## The shallow nesting rule

No more than two opening delimiters — parentheses, brackets, or braces — before
a corresponding close.

```go
name := strings.ToLower(strings.TrimSpace(strings.ReplaceAll(raw, "_", " ")))
```

`strings.ToLower(` is one open. `strings.TrimSpace(` is two.
`strings.ReplaceAll(` is three. Three levels deep before anything resolves, all
to clean up a string.

```go
spaced := strings.ReplaceAll(raw, "_", " ")
name := strings.ToLower(strings.TrimSpace(spaced))
```

Neither line nests past two.

Brackets count. Map lookups are delimiter pairs:

```go
name := users[groups[ids[index]]]
```

Three opens.

```go
id := groups[ids[index]]
name := users[id]
```

## Why two rules

They catch different things.

```go
result := process(transform(x, y), z)
```

Two opens — nesting is fine. But `x, y` belongs to `transform` while
`transform(x, y), z` belongs to `process`. Commas at two levels. Only the
uniform comma rule flags this.

```go
value := outer(middle(inner()))
```

No commas. Three opens before the first close. Only the shallow nesting rule
flags this.

Some real offenders trip both:

```go
parts = append(parts, strconv.FormatFloat(math.Abs(val), 'f', 2, 64))
```

Three opens and commas at two levels.

```go
abs := math.Abs(val)
formatted := strconv.FormatFloat(abs, 'f', 2, 64)
parts = append(parts, formatted)
```

The fix is always the same: extract to a named variable. Naming the variable
documents what the expression computes. The outer expression reads in terms of a
word instead of a computation.

Both rules work at the smallest scale: one line, one expression. You can check
them in review without understanding what the program does. As far as I can
tell, no existing linter enforces either rule. Tools like `nestif`, `gocognit`,
and ESLint's `max-depth` check control-flow nesting — `if` inside `if` inside
`if`. None check expression-level delimiter depth or mixed comma membership.

They came from an itch. Certain lines have always struck me as harder to read
than they should be, given how little they do. These rules are the closest I've
come to saying why.
