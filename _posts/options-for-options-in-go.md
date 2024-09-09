---
layout: post
title: Options for Options in Go
date: 2024-08-31 00:00:01 -04:00
categories:
---

A discussion of different ways to represent conditional data in the Go programming language.

In this article, I explore the uses for various strategies in Go for dealing with values that are only conditionally available.  I compare alternatives for implementations, from familiar pointers to full-blown option types with a host of relevant methods inspired by functional programming.
## What is conditional data?

Conditional data is data that is available sometimes, and not others. Let's say, for example, you were fetching a record from the `users` table in a database. The `users` table has columns like `first_name` and `last_name` that are always populated, that is to say, a record can't be created without those columns receiving values. Imagine that the `email_address` field, however, is not always populated, since our application allows a user record to be created before asking for an email.  It's available when we've gotten it into the database We'll make the column in the table nullable to represent this.

```sql
CREATE TABLE users (
    id            INTEGER PRIMARY KEY,
    first_name    TEXT NOT NULL,
    last_name     TEXT NOT NULL,
    email_address TEXT,      -- Nullable column
);
```

When you scan rows from the table into a `User` struct, you can rely on the `FirstName` and `LastName` fields being populated.  However, you can't scan the results into a normal string for the `EmailAddress` field, since the SQL driver will complain about any null value it encounters in the `email_address` column. 

Why does the driver complain?  Because unlike Go, the database doesn't presume to assign a default value its types (unless you configure one for the column, at which point there's not much use for nullability).   And the database can't try to use another value, such as an empty string, to represent the lack of a value, since it can't assume you don't need empty string as a valid value for the column.  To do so would not be accurate, poisoning whatever computations depended on it. Garbage in, garbage out.

The SQL driver gives you two alternatives for scanning such a column; either scan it into a pointer, in which case the value is `nil` when the column is null, or use an option type called `sql.NullString`.  Here's a struct to scan records from our `users` table that illustrates `sql.NullString` for the potentially-missing email address:

```go
type User struct {
    ID           int
    FirstName    string         `db:"first_name"`
    LastName     string         `db:"last_name"`
    EmailAddress sql.NullString `db:"email_address"`
}
```

This is one way that Go developers encounter a formalized option type, albeit a not very sophisticated one.  `sql.NullString` is an option type provided by the `sql` package to handle scanning of such nullable columns. Here's the definition of `sql.NullString` from the standard library:

```sql
// NullString represents a string that may be null.
type NullString struct {
    String string
    Valid  bool // Valid is true if String is not NULL
}
```

`NullString` is a struct containing two fields, the eponymous `String` and a boolean flag `Valid` that indicates whether String has a valid value (if true) or should be ignored because it is invalid (false).

The documentation includes the following usage example:

```go
var s sql.NullString
err := db.QueryRow("SELECT name FROM foo WHERE id=?", id).Scan(&s)
...
if s.Valid {
// use s.String
} else {
// NULL value
}
```

The idea here is that the database returns one of either a valid value or null.  Since the struct has a field for the value, all we need to know is whether it is acceptable to use that field.  The `Valid` field contains such a flag, so when we have a `NullString` variable like `s`,  first we must check the flag with an `if` conditional.  Once you know whether the value is valid, you can use the value in the corresponding branch of the if-statement.

Observe that this simple protocol solves the problem neatly.  We needed some extra piece of information to determine when a given value is valid, and now we can check it before trying to use potentially missing data.

Still, at first blush, as an option type, `sql.NullString` seems like a good one.  Now the SQL driver can explicitly communicate whether the information was fetched and we can scan from the database directly to a string field in our `User` struct.  It allows the consumer of that value to avoid accidentally accessing a field that contains an otherwise usable, but wrong zero value.  Problem solved.

On the other hand, it's not clear at this point what this approach offers over the alternative of a string pointer.  The string pointer receives `nil` if the value is null.  Checking for nil in the pointer actually looks a lot like the `sql.NullString` example we just saw (my code this time), with the `nil` value implicitly playing the role of the formerly explicit `Valid` field:

```go
var s *string
err := db.QueryRow("SELECT name FROM foo WHERE id=?", id).Scan(&s)
...
if s != nil {
// use s by dereferencing it as *s
} else {
// NULL value
}
```

Logically, the outcome is the same.  In  [the words of Russ Cox], language maintainer for Go, "there's no effective difference."  Mechanically, it's slightly different, but looks very similar in use.  Remember that a pointer variable is one that holds a memory address, in this case, the address of a variable of type string.  If no memory for a string has been allocated, then the pointer has no address at which to point, so it instead holds the special value `nil`.  `nil` therefore plays the role of the `false` value of the `Valid` field from `sql.NullString` (`true` is indicated by any non-nil address value).  In order to see whether a value was scanned, we check for `nil` and if there is the address of a string instead, then we know we can use the value by dereferencing the pointer as `*s`.

[the words of Russ Cox]: https://groups.google.com/g/golang-nuts/c/vOTFu2SMNeA/m/GB5v3JPSsicJ#c3

There are points to consider when choosing between two such implementations, `sql.NullString` or a string pointer.  We'll explore this more deeply as we progress through the article.  The point, for the moment, is simply that there is more than one way to approach conditionally-present values, even more than one way than is blessed by the maintainers of the language sometimes.

Option types are an increasingly popular concept for dealing with conditional values, with a wide cross-section of popular languages supporting a well-known and, in some cases, standardized option type.  Some lean on option types as a core language feature, such as Rust.  Why?  What are the uses for option types?
## Option types

[According to Wikipedia], 

[According to Wikipedia]: https://en.wikipedia.org/wiki/Option_type

> an **option type** or **maybe type** is a polymorphic type that represents encapsulation of an optional value; e.g., it is used as the return type of functions which may or may not return a meaningful value when they are applied.

If you're like me, you can read that and come away feeling unenlightened.  What it's trying to say is that an option type is generally a container for a value, e.g. a struct such as we saw with `sql.NullString`.  In order for an option type to be useful, we should expect to be able to create one that holds a value irrespective of type, so we don't have to know (or define) a specific option type for values of each type we might want it to hold.  That's the "polymorphic" part of the definition, and one that is best satisfied in Go 1.18 and later with the help of [generics support].

[generics support]: https://go.dev/blog/intro-generics

The other part of the definition reflects the inclusion of a conditional flag (or other mechanism such as a pointer) to indicate whether a value is included or not in the resulting option instance.  This refers to the support for data in the resulting struct supporting such a conditional test, but it can also mean more.  As we'll see, there is actually an entire vocabulary of methods conceptually associated with option types that makes working with them more concise.  Some of these can greatly enhance the readability of code that otherwise is forced to nest logic in conditionals, sometimes to the point of distraction from the actual work being done.

And Go is in good company here.  [Python], [C++], [Java], [Rust], [Swift], [Haskell], [OCaml] and [Zig] have option type support.  Other languages such as [Ruby] and [Kotlin] have "safe navigation operators" for nullable types that provide (albeit limited) functionality of option types.

[Python]: https://docs.python.org/3/library/typing.html#typing.Optional
[C++]: https://devblogs.microsoft.com/cppblog/stdoptional-how-when-and-why/
[Java]: https://www.oracle.com/technical-resources/articles/java/java8-optional.html]
[Rust]: https://doc.rust-lang.org/std/option/
[Swift]: https://developer.apple.com/documentation/swift/optional
[Haskell]: https://hackage.haskell.org/package/base-4.20.0.1/docs/Data-Maybe.html
[OCaml]: https://ocaml.org/manual/5.2/api/Option.html
[Zig]: https://ziglang.org/documentation/master/#Optional-Type
[Ruby]: https://docs.ruby-lang.org/en/master/syntax/calling_methods_rdoc.html#label-Safe+Navigation+Operator
[Kotlin]: https://kotlinlang.org/docs/null-safety.html

The range of implementations of option types varies significantly between the languages, usually based on how heavily the language encourages its use as well as how friendly the language is to functional programming concepts in general.  FP-heavy languages have featureful implementations with support from the language syntax.  Others treat them simply as libraries, usually types with methods.  R