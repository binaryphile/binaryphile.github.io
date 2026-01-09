---
layout: post
title: "Tran Functional Programming Guide"
date: 2026-01-09 12:00:00 -05:00
categories: [ functional-programming, go, software-engineering ]
---

A practical guide to functional programming principles, extracted from Minh Quang Tran's *The Art of Functional Programming* (2024). Go-focused examples using [fluentfp](https://github.com/binaryphile/fluentfp), with OCaml originals for FP-specific concepts.

**This guide serves two purposes:**
1. **FP theory** — Tran's principles of abstraction, composition, and immutability
2. **FP practice** — Complete fluentfp API reference with examples (see [Section 22](#22-fluentfp-quick-reference))

---

Tran's book distills functional programming to its essence: abstraction and composition. These aren't just academic concepts—they're why FP code tends to be shorter, more reusable, and easier to test. I've been applying these patterns with [fluentfp](https://github.com/binaryphile/fluentfp) in Go, and they've changed how I think about collection processing. This guide captures the ideas I reach for most often.

---

## 1. The Goal: Abstraction and Composition

Functional programming excels at two things: **abstraction** and **composition**.

**Abstraction** = capturing general computation patterns as reusable functions
**Composition** = building complex programs from simpler building blocks

These aren't new ideas. But FP takes them further than imperative programming by:

- Treating functions as first-class values (pass them around like data)
- Eliminating side effects (functions always return same output for same input)
- Using immutable data (never modify, only create new)

> "Functional programming excels at abstraction and composition."

The result: code that's easier to understand, test, and compose into larger systems.

---

## 2. Why FP Matters

### The von Neumann Bottleneck

Imperative programming is conceptually tied to the von Neumann architecture:
- Program = sequence of instructions
- Main task = move data between CPU and memory
- Primary concern = updating memory cells stepwise

This makes abstraction and composition *harder*:

```java
// Imperative: sequence of memory updates
int sum = 0; i = 0;
while (i <= n) {
   i = i + 1;
   sum = sum + i * i;
}
```

The loop is a single unit. Can't break it into smaller reusable components.

### Functional Approach

```ocaml
(* Functional: composition of reusable parts *)
(fold (+) 0 . map square) [1..n]
```

Built from reusable components: `map`, `fold`, function composition (`.`).

Only the square function and `+` are specific to this program—everything else is general-purpose.

### Declarative vs Imperative

| Imperative | Functional |
|------------|------------|
| *How* to compute step-by-step | *What* the result should be |
| Mental execution required | Structure reveals intent |
| Statements change state | Expressions evaluate to values |

The declarative trend extends beyond FP: Maven over Ant, React over jQuery, Terraform over scripts.

---

## 3. Everything is an Expression

In imperative languages, constructs split into two worlds:
- **Expressions**: evaluate to values (`1 + 2`, `"hello"`)
- **Statements**: perform actions (`if`, `while`, assignment)

In FP, **everything is an expression**. There are no statements.

### The Closure Property

Why does this matter? The **closure property**:

> "An operation for combining data objects satisfies the closure property if the results of combining things with that operation can themselves be combined using the same operation."

Think LEGO: connect two bricks, get a new brick that can connect to other bricks.

In FP:
- Combine two expressions → get a new expression
- That expression can combine with other expressions
- Unlimited composability

### If as Expression

Imperative `if` is a statement:
```java
// Java: can't use if inside an expression
int x = (if (a > b) { return a; } else { return b; }); // ERROR
```

Functional `if` is an expression:
```ocaml
(* OCaml: if evaluates to a value *)
let x = if a > b then a else b
```

This enables composition:
```ocaml
(* Can use if-expression as operand *)
(if 1 > 2 then 0 else 42) + 10  (* Result: 52 *)
```

### Go Parallel

Go lacks a ternary operator, but fluentfp provides one:

```go
import "github.com/binaryphile/fluentfp/ternary"

// Fluent ternary expression
max := ternary.If[int](a > b).Then(a).Else(b)

// For expensive computations, use ThenCall/ElseCall to defer evaluation
result := ternary.If[string](cached).
    Then(cachedValue).
    ElseCall(expensiveComputation)
```

The `Then`/`Else` values are evaluated immediately (like function arguments). Use `ThenCall`/`ElseCall` when the value computation is expensive and should only run if selected.

---

## 4. Lambda Calculus: The Foundation

Lambda calculus is the theoretical foundation of all functional programming.

### Three Building Blocks

Only three constructs exist:

| Construct | Example | Meaning |
|-----------|---------|---------|
| Variable | `x`, `y` | Name for a value |
| Function abstraction | `λx. x` | Anonymous function taking x, returning x |
| Function application | `f x` | Apply function f to argument x |

Despite this simplicity, lambda calculus is **Turing-complete**—as powerful as any programming language.

### Function Abstraction

Mathematical function: f(x) = x * x
Lambda calculus: λx. x * x

In OCaml:
```ocaml
(* Anonymous function *)
fun x -> x * x

(* Named function *)
let square = fun x -> x * x

(* Syntactic sugar *)
let square x = x * x
```

In Go:
```go
// Anonymous function
func(x int) int { return x * x }

// Named function
square := func(x int) int { return x * x }

// Function declaration
func square(x int) int { return x * x }
```

### Lambda Reduction

To evaluate: substitute argument into function body.

```
(λx. x * x) 3
→ 3 * 3
→ 9
```

Simple concept, profound implications.

---

## 5. First-Class Functions

Functions are **first-class citizens** when they can be:
- Assigned to variables
- Passed as arguments
- Returned from other functions

### Imperative Languages: Second-Class Functions

In traditional imperative languages, functions are special—they can't be treated like data:

```java
// Java (before lambdas): can't assign method to variable
double square(int x) { return x * x; }
// Can't do: var f = square;
```

### FP: Functions Are Values

```ocaml
(* OCaml: function is just a value *)
let square = fun x -> x * x
let apply_twice f x = f (f x)
apply_twice square 2  (* Result: 16 *)
```

In Go:
```go
// Go: functions are first-class
square := func(x int) int { return x * x }
applyTwice := func(f func(int) int, x int) int {
    return f(f(x))
}
applyTwice(square, 2)  // Result: 16
```

This enables **higher-order functions**—the hallmark of FP.

---

## 6. Currying and Partial Application

### Multi-Argument Functions

Lambda calculus only allows single-argument functions. But we can represent multi-argument functions as **chains of single-argument functions**:

```
λx. λy. x + y
```

This is **currying** (named after Haskell Curry).

### How It Works

Apply one argument at a time:

```
(λx. λy. x + y) 3 5
→ (λy. 3 + y) 5
→ 3 + 5
→ 8
```

### Partial Application

Stop before applying all arguments:

```ocaml
(* OCaml *)
let add x y = x + y
let add3 = add 3       (* Partial application: fix x=3 *)
add3 5                 (* Result: 8 *)
```

In Go:
```go
// Go: explicit closure for partial application
func add(x int) func(int) int {
    return func(y int) int { return x + y }
}
add3 := add(3)
add3(5)  // Result: 8
```

**Why it matters**: Create specialized functions from general ones without rewriting.

---

## 7. Higher-Order Functions

Functions that take other functions as arguments or return functions as results.

### Climbing the Abstraction Hierarchy

From specific:
```ocaml
let rec sum_integers a b = if a > b then 0 else a + sum_integers (a+1) b
let rec sum_squares a b = if a > b then 0 else (a*a) + sum_squares (a+1) b
```

To general:
```ocaml
let rec accumulate f init a b =
  if a > b then init
  else f a (accumulate f init (a+1) b)

let sum_integers = accumulate (+) 0
let sum_squares = accumulate (fun x acc -> x*x + acc) 0
```

One function captures the pattern. Specific versions are just configurations.

**Taking it too far:** Don't abstract prematurely. If you only have `sumIntegers` and `sumSquares`, two explicit functions might be clearer than `accumulate`. Abstract when you have *three or more* variations, or when the pattern is genuinely reusable.

### Go Example

```go
// Specific functions
func sumIntegers(a, b int) int {
    sum := 0
    for i := a; i <= b; i++ { sum += i }
    return sum
}

func sumSquares(a, b int) int {
    sum := 0
    for i := a; i <= b; i++ { sum += i * i }
    return sum
}

// General pattern
func accumulate(f func(int, int) int, init, a, b int) int {
    result := init
    for i := a; i <= b; i++ {
        result = f(i, result)
    }
    return result
}

// Specific as configurations
sumIntegers := func(a, b int) int {
    return accumulate(func(x, acc int) int { return x + acc }, 0, a, b)
}
sumSquares := func(a, b int) int {
    return accumulate(func(x, acc int) int { return x*x + acc }, 0, a, b)
}
```

---

## 8. Recursion: The FP Loop

FP has no `for` or `while` loops. Repeated computation uses **recursion**.

### Why No Loops?

Loops require mutable state:
```java
// Must mutate sum and i
int sum = 0;
for (int i = 0; i < n; i++) {
    sum += i;
}
```

Recursion uses immutable values:
```ocaml
let rec sum n =
  if n = 0 then 0
  else n + sum (n - 1)
```

Each recursive call creates new bindings. Nothing is mutated.

### Tail Recursion

Problem: deep recursion blows the stack.

Solution: **tail recursion**—recursive call is the last operation.

```ocaml
(* Not tail-recursive: must compute n + result after recursive call *)
let rec sum n = if n = 0 then 0 else n + sum (n - 1)

(* Tail-recursive: recursive call is last operation *)
let rec sum_tail acc n = if n = 0 then acc else sum_tail (acc + n) (n - 1)
let sum n = sum_tail 0 n
```

Tail-recursive functions can be optimized to loops (constant stack space).

### Go Pattern

```go
// Iteration (Go's natural style)
func sum(n int) int {
    result := 0
    for i := 1; i <= n; i++ {
        result += i
    }
    return result
}

// Recursive style (for FP patterns)
func sumRec(n int) int {
    if n == 0 {
        return 0
    }
    return n + sumRec(n-1)
}

// Tail-recursive with accumulator
func sumTail(acc, n int) int {
    if n == 0 {
        return acc
    }
    return sumTail(acc+n, n-1)
}
```

Go doesn't optimize tail calls, so iteration is usually preferred.

---

## 9. Compound Data Types

### Tuples: Fixed-Size Heterogeneous Collections

```ocaml
(* OCaml: tuple of different types *)
let person = ("Alice", 30, true)  (* string * int * bool *)

(* Destructure with pattern matching *)
let (name, age, active) = person
```

Go parallel:
```go
// Go: use struct for named tuples
type Person struct {
    Name   string
    Age    int
    Active bool
}

// Or multiple return values (unnamed tuple)
func getPerson() (string, int, bool) {
    return "Alice", 30, true
}
name, age, active := getPerson()
```

### Lists: Variable-Size Homogeneous Collections

```ocaml
(* OCaml: list construction *)
let nums = [1; 2; 3]
let more = 0 :: nums  (* Prepend: [0; 1; 2; 3] *)

(* Pattern matching to destructure *)
let head :: tail = nums  (* head=1, tail=[2;3] *)
```

Key insight: Lists are **immutable**. `0 :: nums` creates a *new* list.

### Algebraic Data Types

Combine types with **AND** (product) and **OR** (sum):

```ocaml
(* Product type: AND *)
type point = { x: float; y: float }  (* x AND y *)

(* Sum type: OR *)
type shape =
  | Circle of float          (* radius *)
  | Rectangle of float * float  (* width * height *)
```

Go parallel:
```go
// Product type (struct)
type Point struct {
    X, Y float64
}

// Sum type (interface + variants)
type Shape interface {
    Area() float64
}

type Circle struct {
    Radius float64
}

type Rectangle struct {
    Width, Height float64
}
```

### Pattern Matching

Destructure and dispatch in one construct:

```ocaml
let area shape =
  match shape with
  | Circle r -> 3.14159 *. r *. r
  | Rectangle (w, h) -> w *. h
```

Go parallel:
```go
func area(s Shape) float64 {
    switch v := s.(type) {
    case Circle:
        return math.Pi * v.Radius * v.Radius
    case Rectangle:
        return v.Width * v.Height
    default:
        return 0
    }
}
```

### The Option Type

The most common sum type: **Option** (or Maybe)—a value that might not exist.

```ocaml
(* OCaml: option type *)
type 'a option = None | Some of 'a

(* Safe division *)
let safe_div x y =
  if y = 0 then None
  else Some (x / y)

(* Using pattern matching *)
match safe_div 10 2 with
| None -> "undefined"
| Some n -> string_of_int n
```

Go with fluentfp:
```go
import "github.com/binaryphile/fluentfp/option"

// Create options
found := option.Of("hello")           // Ok option with value
missing := option.NotOk[string]()     // Not-ok option (explicit factory)
// Also valid: option.Basic[string]{} - zero value is not-ok

// From pointer (nil-safe conversion)
var ptr *string = nil
opt := option.FromOpt(ptr)            // Not-ok if nil

// From comparable (zero-value safe)
opt := option.IfProvided("")          // Not-ok if empty string

// Unwrap with defaults
value := opt.Or("default")            // Value or default
value := opt.OrEmpty()                // Value or zero value
value := opt.OrCall(expensiveFn)      // Value or lazy default

// Check and extract
if val, ok := opt.Get(); ok {
    // Use val
}

// Transform (map over option) - type-specific methods
opt.ToInt(func(s string) int { return len(s) })  // Option[int]

// Transform - generic Map function (for any return type)
type User struct { Name string }
userOpt := option.Map(opt, func(s string) User { return User{Name: s} })

// Filter
opt.KeepOkIf(func(s string) bool { return len(s) > 0 })

// Environment variables (returns Option[string])
port := option.Getenv("PORT").Or("8080")
```

**Advanced option methods:**
```go
// Check status without extracting
if opt.IsOk() {
    // proceed knowing value exists
}

// Panic-based unwrap (use sparingly, for cases where not-ok is a bug)
value := opt.MustGet()  // panics if not-ok

// Filter with negation (complement of KeepOkIf)
nonEmpty := opt.ToNotOkIf(func(s string) bool { return s == "" })

// Side effect without extracting
opt.Call(func(s string) { log.Println("Found:", s) })

// Convert back to pointer (for APIs expecting *T)
ptr := opt.ToOpt()  // nil if not-ok, *value if ok

// Transform to same type
upper := opt.ToSame(strings.ToUpper)
```

The Option type makes "might not exist" explicit in the type system rather than using nil/null conventions.

---

## 10. Immutability

In FP, data is **immutable**. Once created, it never changes.

### Why Immutability?

1. **No hidden state changes**: Function behavior is predictable
2. **Thread-safe by default**: No race conditions
3. **Easy to reason about**: What you see is what you get
4. **Enables structural sharing**: New versions share unchanged parts

### Immutable Updates

Instead of mutating, create new values with changes:

```ocaml
(* OCaml: "update" creates new record *)
let p1 = { x = 1.0; y = 2.0 }
let p2 = { p1 with x = 3.0 }  (* New record: { x=3.0, y=2.0 } *)
(* p1 is unchanged *)
```

Go pattern:
```go
// Immutable update pattern
func (p Point) WithX(x float64) Point {
    return Point{X: x, Y: p.Y}
}

p1 := Point{X: 1.0, Y: 2.0}
p2 := p1.WithX(3.0)  // p1 unchanged
```

### List Operations Are Non-Destructive

```ocaml
let xs = [1; 2; 3]
let ys = 0 :: xs     (* ys = [0;1;2;3], xs unchanged *)
let zs = List.map (fun x -> x * 2) xs  (* zs = [2;4;6], xs unchanged *)
```

**Taking it too far:** Immutability has costs. In Go, each FP operation allocates a new slice. For hot paths with large data, profile before committing to functional style. Sometimes a mutable loop is the right choice.

---

## 11. Map: Transform Each Element

The `map` function applies a transformation to every element:

```
map f [a, b, c] = [f(a), f(b), f(c)]
```

### Basic Usage

```ocaml
(* OCaml *)
List.map (fun x -> x * x) [1; 2; 3]
(* Result: [1; 4; 9] *)
```

Go:
```go
// Go (with fluentfp)
import "github.com/binaryphile/fluentfp/slice"

squares := slice.From([]int{1, 2, 3}).ToInt(square)
// Result: [1, 4, 9]

// Or inline
slice.From([]int{1, 2, 3}).ToInt(func(x int) int { return x * x })

// Convert: same-type transformation (T → T)
doubled := slice.From([]int{1, 2, 3}).Convert(func(x int) int { return x * 2 })
// Result: [2, 4, 6]
```

Use `Convert` when the output type matches the input type. Use `ToInt`, `ToString`, etc. when converting to a different type.

### Key Insight: Map Preserves Structure

Map transforms elements but preserves the container's shape:
- List of 3 elements → List of 3 elements
- Tree structure → Same tree structure
- Optional value → Optional value

```
map: (a → b) → Container[a] → Container[b]
```

### Map as Lifting

Think of `map` as **lifting** a function to work on containers:

```
square: int → int
map square: []int → []int
```

Regular function becomes container-aware without knowing about containers.

**Taking it too far:** Don't chain map operations when a single pass suffices. `slice.From(xs).ToInt(f).ToInt(g)` creates two intermediate slices. For performance-critical code, combine: `slice.From(xs).ToInt(func(x int) int { return g(f(x)) })`.

---

## 12. Filter: Select Elements

The `filter` function keeps only elements satisfying a predicate:

```ocaml
(* OCaml *)
List.filter (fun x -> x mod 2 = 0) [1; 2; 3; 4; 5]
(* Result: [2; 4] *)
```

Go:
```go
import "github.com/binaryphile/fluentfp/slice"

isEven := func(x int) bool { return x%2 == 0 }
evens := slice.From([]int{1, 2, 3, 4, 5}).KeepIf(isEven)
// Result: [2, 4]

// RemoveIf: the complement (remove matching elements)
odds := slice.From([]int{1, 2, 3, 4, 5}).RemoveIf(isEven)
// Result: [1, 3, 5]
```

`KeepIf` and `RemoveIf` are complements. Use whichever reads more naturally for your predicate.

### Composing Predicates

Build complex filters from simple ones:

```ocaml
let is_even x = x mod 2 = 0
let is_positive x = x > 0
let both p1 p2 x = p1 x && p2 x

List.filter (both is_even is_positive) [-2; -1; 0; 1; 2; 3; 4]
(* Result: [2; 4] *)
```

Go:
```go
// Compose predicates with simple function
func both[T any](p1, p2 func(T) bool) func(T) bool {
    return func(x T) bool { return p1(x) && p2(x) }
}

isEven := func(x int) bool { return x%2 == 0 }
isPositive := func(x int) bool { return x > 0 }

slice.From(nums).KeepIf(both(isEven, isPositive))
```

### Additional Slice Operations

```go
// TakeFirst: get first N elements
top3 := slice.From(scores).TakeFirst(3)

// Each: apply side effect to each element (use sparingly)
slice.From(users).Each(func(u User) { log.Println(u.Name) })

// Len: get length (useful for method chaining)
count := slice.From(items).KeepIf(isValid).Len()
```

`Each` is for side effects and doesn't return a value—use it at the end of pipelines for I/O operations.

---

## 13. Fold: Reduce to Single Value

The `fold` function combines all elements into one value:

```
fold f init [a, b, c] = f(a, f(b, f(c, init)))
```

### Basic Usage

```ocaml
(* OCaml *)
List.fold_right (+) [1; 2; 3; 4] 0
(* Result: 10 *)

List.fold_right ( * ) [1; 2; 3; 4] 1
(* Result: 24 *)
```

Go:
```go
import "github.com/binaryphile/fluentfp/slice"

sum := func(acc, x int) int { return acc + x }
total := slice.Fold([]int{1, 2, 3, 4}, 0, sum)
// Result: 10
```

### Fold Is Universal

Many list operations can be expressed as fold:

```ocaml
(* length via fold *)
let length l = List.fold_right (fun _ acc -> acc + 1) l 0

(* map via fold *)
let map f l = List.fold_right (fun x acc -> f x :: acc) l []

(* filter via fold *)
let filter p l = List.fold_right (fun x acc -> if p x then x :: acc else acc) l []

(* any: true if any element satisfies predicate *)
let any p l = List.fold_right (fun x acc -> p x || acc) l false

(* all: true if all elements satisfy predicate *)
let all p l = List.fold_right (fun x acc -> p x && acc) l true
```

> Fold is the "universal" list function. Map, filter, and more are special cases.

**Taking it too far:** Just because you *can* implement everything as fold doesn't mean you *should*. `slice.From(xs).KeepIf(pred)` is clearer than a fold that reconstructs a filtered list. Use fold when you genuinely need to reduce to a different type.

### fold_left vs fold_right

```
fold_right f [a,b,c] init = f(a, f(b, f(c, init)))  (* Right to left *)
fold_left f init [a,b,c] = f(f(f(init, a), b), c)   (* Left to right *)
```

`fold_left` is tail-recursive and more efficient for large lists.

---

## 14. Zip: Combine Two Lists

The `zip` function pairs elements from two lists:

```ocaml
(* OCaml *)
let rec zip l1 l2 = match (l1, l2) with
  | ([], _) -> []
  | (_, []) -> []
  | (h1::t1, h2::t2) -> (h1, h2) :: zip t1 t2

zip [1; 2; 3] ["a"; "b"; "c"]
(* Result: [(1, "a"); (2, "b"); (3, "c")] *)
```

### zipWith: Combine with Function

```ocaml
let rec zipWith f l1 l2 = match (l1, l2) with
  | ([], _) -> []
  | (_, []) -> []
  | (h1::t1, h2::t2) -> f h1 h2 :: zipWith f t1 t2

zipWith (+) [1; 2; 3] [10; 20; 30]
(* Result: [11; 22; 33] *)
```

Go with fluentfp:
```go
import "github.com/binaryphile/fluentfp/tuple/pair"

// Zip two slices into pairs
names := []string{"Alice", "Bob", "Carol"}
ages := []int{30, 25, 35}
pairs := pair.Zip(names, ages)
// Result: [{Alice 30}, {Bob 25}, {Carol 35}]

// ZipWith applies a function to corresponding elements
add := func(a, b int) int { return a + b }
sums := pair.ZipWith([]int{1, 2, 3}, []int{10, 20, 30}, add)
// Result: [11, 22, 33]

// Create a single pair
p := pair.Of("key", 42)  // Pair[string, int]
```

Note: fluentfp's Zip panics if slices have different lengths. Check lengths first if unsure.

---

## 15. Dataflow Programming

### Functions as Dataflow Components

Think of FP functions as components in a data pipeline:

```
Input → [filter] → [map] → [fold] → Output
```

Each function:
- Accepts input
- Produces output
- Has no side effects

### Composition Example

Sum of squares of even numbers:

```ocaml
(* OCaml: dataflow style with pipe operator *)
let sum_even_squares a b =
  enumerate_integers a b
  |> List.filter (fun x -> x mod 2 = 0)
  |> List.map (fun x -> x * x)
  |> List.fold_left (+) 0

sum_even_squares 1 10
(* Result: 220 *)
```

Go:
```go
func sumEvenSquares(nums []int) int {
    isEven := func(x int) bool { return x%2 == 0 }
    square := func(x int) int { return x * x }
    sum := func(acc, x int) int { return acc + x }

    evens := slice.From(nums).KeepIf(isEven)
    squares := slice.From(evens).ToInt(square)
    return slice.Fold(squares, 0, sum)
}
```

### Unix Philosophy Parallel

Eric Raymond's Rule of Composition:

> "Favor small, independent programs that do one thing and do it well... build programs whose inputs and outputs are text streams."

```bash
cat file.txt | grep "error" | sort | uniq -c
```

Same principle: small, composable units with standard interfaces.

---

## 16. Lazy Evaluation and Streams

### Call-by-Value vs Call-by-Name

**Call-by-value** (OCaml, Go, most languages): Evaluate arguments before applying function.

**Call-by-name** (Haskell): Substitute argument into function body unevaluated.

```
(λy. z) (infinite-loop)
```

Call-by-value: hangs forever (tries to evaluate infinite-loop first)
Call-by-name: returns z immediately (never needs the argument)

### Streams: Delayed Lists

Lists eagerly compute all elements. Streams compute elements on demand.

```ocaml
(* OCaml: stream type *)
type 'a stream = Nil | Cons of 'a * (unit -> 'a stream)

(* Infinite stream of integers from n *)
let rec from n = Cons (n, fun () -> from (n + 1))

(* Take first k elements *)
let rec take k s = match (k, s) with
  | (0, _) -> []
  | (_, Nil) -> []
  | (n, Cons (x, f)) -> x :: take (n-1) (f ())

take 5 (from 1)
(* Result: [1; 2; 3; 4; 5] *)
```

### Go Channel Pattern

Go channels naturally support lazy evaluation:

```go
// Infinite stream of integers
func integers(start int) <-chan int {
    ch := make(chan int)
    go func() {
        for i := start; ; i++ {
            ch <- i
        }
    }()
    return ch
}

// Take first n
func take[T any](n int, ch <-chan T) []T {
    result := make([]T, 0, n)
    for i := 0; i < n; i++ {
        result = append(result, <-ch)
    }
    return result
}

take(5, integers(1))  // [1, 2, 3, 4, 5]
```

---

## 17. Practical Application: Collections

Real-world collection processing using FP patterns:

### E-Commerce Example

```go
type Product struct {
    Name     string
    Category string
    Price    float64
    InStock  bool
}

// Predicates as methods enable fluent chaining
func (p Product) IsElectronics() bool { return p.Category == "electronics" }
func (p Product) IsInStock() bool     { return p.InStock }
func (p Product) GetPrice() float64   { return p.Price }

// Find average price of in-stock electronics
func avgElectronicsPrice(products []Product) float64 {
    isTarget := func(p Product) bool {
        return p.IsElectronics() && p.IsInStock()
    }

    prices := slice.From(products).KeepIf(isTarget).ToFloat64(Product.GetPrice)

    if len(prices) == 0 {
        return 0
    }

    sum := func(acc, p float64) float64 { return acc + p }
    total := slice.Fold(prices, 0.0, sum)
    return total / float64(len(prices))
}
```

### Method References for Clarity

```go
// fluentfp works elegantly with method references
type Developer struct {
    Name   string
    Status string
}

func (d Developer) IsIdle() bool { return d.Status == "idle" }
func (d Developer) GetName() string { return d.Name }

// Reads like English: "from developers, keep if idle, get names"
idleNames := slice.From(developers).KeepIf(Developer.IsIdle).ToString(Developer.GetName)
```

### Unzip: Extract Multiple Fields Efficiently

When you need multiple fields from each element, use `Unzip` instead of multiple map passes:

```go
type Order struct {
    ID     int
    Amount float64
    Status string
}

// BAD: Two passes over the slice
ids := slice.From(orders).ToInt(Order.GetID)
amounts := slice.From(orders).ToFloat64(Order.GetAmount)

// GOOD: Single pass extracts both
ids, amounts := slice.Unzip2(orders, Order.GetID, Order.GetAmount)

// For 3 fields
ids, amounts, statuses := slice.Unzip3(orders, Order.GetID, Order.GetAmount, Order.GetStatus)

// For 4 fields (e.g., full order extraction)
type FullOrder struct {
    ID        int
    Amount    float64
    Status    string
    Customer  string
}
func (o FullOrder) GetID() int         { return o.ID }
func (o FullOrder) GetAmount() float64 { return o.Amount }
func (o FullOrder) GetStatus() string  { return o.Status }
func (o FullOrder) GetCustomer() string { return o.Customer }

ids, amounts, statuses, customers := slice.Unzip4(
    fullOrders,
    FullOrder.GetID,
    FullOrder.GetAmount,
    FullOrder.GetStatus,
    FullOrder.GetCustomer,
)
```

### Lower-Order Functions (lof)

The `lof` package wraps Go builtins for use with higher-order functions:

```go
import "github.com/binaryphile/fluentfp/lof"

// lof.StringLen wraps len() for strings - usable as function value
lengths := slice.From(words).ToInt(lof.StringLen)

// lof.Println wraps fmt.Println - usable with Each
slice.From(messages).Each(lof.Println)
```

Why? Go's `len` is a builtin, not a function value—you can't pass it directly to `ToInt`. `lof.StringLen` is a regular function that wraps it.

### When to Use fluentfp vs Raw Loops

| Use fluentfp when... | Use raw loops when... |
|----------------------|----------------------|
| Transforming entire collections | Early exit on first match |
| Filtering with clear predicates | Complex multi-step mutations |
| Chaining operations readably | Performance-critical hot paths |
| Method references available | Accumulating into maps/sets |
| You want testable predicates | Index access needed mid-loop |

**Decision flowchart:**
1. **Does the operation fit map/filter/fold?** → Use fluentfp
2. **Need early exit (break)?** → Use raw loop
3. **Accumulating into a map?** → Use raw loop (Go maps aren't functional)
4. **Performance-critical inner loop?** → Profile first, then decide
5. **Readability improves with chaining?** → Use fluentfp

**Example: When raw loop wins**
```go
// BAD: fluentfp forces full iteration
found := slice.From(users).KeepIf(User.IsAdmin)
if len(found) > 0 {
    return found[0]  // Only needed first match
}

// GOOD: raw loop with early exit
for _, u := range users {
    if u.IsAdmin() {
        return u  // Stop immediately
    }
}
```

**Example: When fluentfp wins**
```go
// GOOD: clear transformation pipeline
activeNames := slice.From(users).
    KeepIf(User.IsActive).
    ToString(User.GetName)

// WORSE: harder to read
var activeNames []string
for _, u := range users {
    if u.IsActive() {
        activeNames = append(activeNames, u.GetName())
    }
}
```

---

## 18. Practical Application: JSON

Algebraic data types naturally represent JSON:

```ocaml
(* OCaml: JSON as ADT *)
type json =
  | JsonNull
  | JsonBool of bool
  | JsonNumber of float
  | JsonString of string
  | JsonArray of json list
  | JsonObject of (string * json) list
```

### Higher-Order Functions on JSON

```ocaml
(* Map over all values in JSON *)
let rec map_json f j = match j with
  | JsonNull -> JsonNull
  | JsonBool b -> JsonBool (f b)
  | JsonNumber n -> JsonNumber n
  | JsonString s -> JsonString s
  | JsonArray arr -> JsonArray (List.map (map_json f) arr)
  | JsonObject obj -> JsonObject (List.map (fun (k, v) -> (k, map_json f v)) obj)
```

Go parallel with `any` or reflection (less elegant):

```go
// Go: JSON is naturally map[string]any
func mapJSON(j any, f func(any) any) any {
    switch v := j.(type) {
    case map[string]any:
        result := make(map[string]any)
        for k, val := range v {
            result[k] = mapJSON(val, f)
        }
        return result
    case []any:
        result := make([]any, len(v))
        for i, val := range v {
            result[i] = mapJSON(val, f)
        }
        return result
    default:
        return f(v)
    }
}
```

---

## 19. Case Study: Log Analysis Pipeline

A real-world example showing FP principles in action.

### The Problem

Parse server logs to find the top 10 slowest API endpoints:

```
2024-01-15 10:23:45 GET /api/users 234ms 200
2024-01-15 10:23:46 POST /api/orders 1523ms 201
2024-01-15 10:23:47 GET /api/health 12ms 200
```

### Imperative Approach

```go
// Imperative: mutation, nested loops, hard to test
func topSlowEndpoints(lines []string, n int) []Endpoint {
    endpoints := make(map[string][]int)
    for _, line := range lines {
        parts := strings.Fields(line)
        if len(parts) < 5 { continue }
        path := parts[2]
        ms, err := strconv.Atoi(strings.TrimSuffix(parts[3], "ms"))
        if err != nil { continue }
        endpoints[path] = append(endpoints[path], ms)
    }

    var results []Endpoint
    for path, times := range endpoints {
        sum := 0
        for _, t := range times { sum += t }
        results = append(results, Endpoint{path, float64(sum)/float64(len(times))})
    }

    sort.Slice(results, func(i, j int) bool {
        return results[i].AvgMs > results[j].AvgMs
    })

    if len(results) > n { results = results[:n] }
    return results
}
```

### Functional Approach

```go
type LogEntry struct {
    Path   string
    TimeMs int
    Status int
}

func (e LogEntry) GetPath() string { return e.Path }
func (e LogEntry) GetTimeMs() int  { return e.TimeMs }

// Parse: string → LogEntry (pure function)
func parseLogEntry(line string) (LogEntry, bool) {
    parts := strings.Fields(line)
    if len(parts) < 5 {
        return LogEntry{}, false
    }
    ms, err := strconv.Atoi(strings.TrimSuffix(parts[3], "ms"))
    if err != nil {
        return LogEntry{}, false
    }
    return LogEntry{Path: parts[2], TimeMs: ms}, true
}

// Aggregate: []LogEntry → map[string][]int (pure function)
func groupByPath(entries []LogEntry) map[string][]int {
    result := make(map[string][]int)
    for _, e := range entries {
        result[e.Path] = append(result[e.Path], e.TimeMs)
    }
    return result
}

// Average: []int → float64 (pure function)
func average(times []int) float64 {
    sum := slice.Fold(times, 0, func(a, b int) int { return a + b })
    return float64(sum) / float64(len(times))
}

// Compose the pipeline
func topSlowEndpoints(lines []string, n int) []Endpoint {
    // 1. Parse valid entries
    entries := make([]LogEntry, 0)
    for _, line := range lines {
        if e, ok := parseLogEntry(line); ok {
            entries = append(entries, e)
        }
    }

    // 2. Group by path and compute averages
    byPath := groupByPath(entries)
    results := make([]Endpoint, 0, len(byPath))
    for path, times := range byPath {
        results = append(results, Endpoint{path, average(times)})
    }

    // 3. Sort and take top n
    sort.Slice(results, func(i, j int) bool {
        return results[i].AvgMs > results[j].AvgMs
    })

    if len(results) > n {
        return results[:n]
    }
    return results
}
```

### Why FP Helps Here

| Aspect | Imperative | Functional |
|--------|------------|------------|
| **Testing** | Hard—requires logs, checks mutation | Easy—test `parseLogEntry`, `average` in isolation |
| **Reuse** | None—logic tangled in one function | `average` works anywhere |
| **Debugging** | Step through nested loops | Inspect intermediate results |
| **Change** | Risky—one change affects everything | Safe—swap components |

The functional version isn't shorter, but each piece is **testable in isolation**. If `average` is correct and `parseLogEntry` is correct, the composition is likely correct.

---

## 20. Summary: Core Principles

### The Two Pillars

| Pillar | Meaning | Enabled By |
|--------|---------|------------|
| **Abstraction** | Capture patterns as reusable functions | Higher-order functions |
| **Composition** | Build complex from simple | Pure functions, immutability |

### Key Techniques

| Technique | Description |
|-----------|-------------|
| First-class functions | Functions as values, pass and return them |
| Higher-order functions | Functions that take or return functions |
| Currying | Multi-arg function as chain of single-arg functions |
| Partial application | Fix some arguments, get specialized function |
| Pattern matching | Destructure and dispatch on shape |
| Immutability | Never mutate, only create new |
| Recursion | Loops via function calling itself |

### Core Computation Patterns

| Function | Purpose | Type Signature |
|----------|---------|----------------|
| `map` | Transform each element | `(a → b) → [a] → [b]` |
| `filter` | Keep elements matching predicate | `(a → bool) → [a] → [a]` |
| `fold` | Reduce to single value | `(a → b → b) → b → [a] → b` |
| `zip` | Pair elements from two lists | `[a] → [b] → [(a, b)]` |

### Dataflow Mindset

Think of programs as pipelines:

```
Data → [filter] → [map] → [fold] → Result
```

Small, focused functions. Standard interfaces. Compose freely.

---

## 21. Quick Reference for CLAUDE.md

```markdown
### Functional Programming: Tran's Principles

**Core insight:** FP excels at abstraction (reusable patterns) and composition (building complex from simple).

**First-class functions:**
- Assign functions to variables
- Pass functions as arguments
- Return functions from functions

**Key patterns:**
| Pattern | Purpose | Example |
|---------|---------|---------|
| map | Transform each element | `map square [1,2,3] = [1,4,9]` |
| filter | Keep matching elements | `filter even [1,2,3,4] = [2,4]` |
| fold | Reduce to single value | `fold (+) 0 [1,2,3,4] = 10` |

**Immutability:** Never mutate data. Create new values with changes.

**Composition:** Connect functions via shared interfaces:
```
data |> filter pred |> map transform |> fold combine init
```

**Everything is an expression:** No statements. If-then-else evaluates to a value.

**Algebraic data types:**
- Product types (AND): struct with fields
- Sum types (OR): interface with variants
- Pattern matching: destructure + dispatch
```

---

## 22. fluentfp Quick Reference

Complete API reference for [fluentfp](https://github.com/binaryphile/fluentfp):

### slice package

| Function | Signature | Purpose |
|----------|-----------|---------|
| `From` | `From[T]([]T) Mapper[T]` | Create fluent slice |
| `KeepIf` | `.KeepIf(func(T) bool)` | Filter (keep matching) |
| `RemoveIf` | `.RemoveIf(func(T) bool)` | Filter (remove matching) |
| `Convert` | `.Convert(func(T) T)` | Map same type |
| `ToInt` | `.ToInt(func(T) int)` | Map to int |
| `ToString` | `.ToString(func(T) string)` | Map to string |
| `ToFloat64` | `.ToFloat64(func(T) float64)` | Map to float64 |
| `ToBool` | `.ToBool(func(T) bool)` | Map to bool |
| `ToAny` | `.ToAny(func(T) any)` | Map to any |
| `Each` | `.Each(func(T))` | Side effect per element |
| `TakeFirst` | `.TakeFirst(n int)` | First n elements |
| `Len` | `.Len() int` | Slice length |
| `Fold` | `Fold[T,R]([]T, R, func(R,T)R)` | Reduce to single value |
| `Unzip2` | `Unzip2[T,A,B]([]T, fa, fb)` | Extract 2 fields in one pass |
| `Unzip3` | `Unzip3[T,A,B,C]([]T, fa, fb, fc)` | Extract 3 fields |
| `Unzip4` | `Unzip4[T,A,B,C,D]([]T, fa, fb, fc, fd)` | Extract 4 fields |

### option package

| Function | Signature | Purpose |
|----------|-----------|---------|
| `Of` | `Of[T](T) Basic[T]` | Create ok option |
| `NotOk` | `NotOk[T]() Basic[T]` | Create not-ok option |
| `New` | `New[T](T, bool) Basic[T]` | Create from value + ok |
| `FromOpt` | `FromOpt[T](*T) Basic[T]` | From pointer (nil-safe) |
| `IfProvided` | `IfProvided[T comparable](T)` | Not-ok if zero value |
| `Getenv` | `Getenv(string) String` | From environment variable |
| `Map` | `Map[T,R](Basic[T], func(T)R)` | Transform value |
| `.Get` | `.Get() (T, bool)` | Unwrap with ok |
| `.IsOk` | `.IsOk() bool` | Check if ok |
| `.MustGet` | `.MustGet() T` | Unwrap or panic |
| `.Or` | `.Or(T) T` | Value or default |
| `.OrCall` | `.OrCall(func() T) T` | Value or lazy default |
| `.OrEmpty` | `.OrEmpty() T` | Value or zero (for strings) |
| `.OrZero` | `.OrZero() T` | Value or zero (generic) |
| `.OrFalse` | `.OrFalse() T` | Value or zero (for bools) |
| `.KeepOkIf` | `.KeepOkIf(func(T) bool)` | Filter option |
| `.ToNotOkIf` | `.ToNotOkIf(func(T) bool)` | Filter with negation |
| `.ToInt` | `.ToInt(func(T) int)` | Transform to int option |
| `.ToSame` | `.ToSame(func(T) T)` | Transform same type |
| `.Call` | `.Call(func(T))` | Side effect if ok |
| `.ToOpt` | `.ToOpt() *T` | Convert to pointer |

### ternary package

| Function | Signature | Purpose |
|----------|-----------|---------|
| `If` | `If[R](bool) Ternary[R]` | Start ternary |
| `.Then` | `.Then(R) Ternary[R]` | Value if true |
| `.ThenCall` | `.ThenCall(func() R)` | Lazy value if true |
| `.Else` | `.Else(R) R` | Value if false, returns result |
| `.ElseCall` | `.ElseCall(func() R) R` | Lazy value if false |

### tuple/pair package

| Function | Signature | Purpose |
|----------|-----------|---------|
| `Of` | `Of[A,B](A, B) X[A,B]` | Create pair |
| `Zip` | `Zip[A,B]([]A, []B) []X[A,B]` | Zip two slices |
| `ZipWith` | `ZipWith[A,B,R]([]A, []B, func(A,B)R)` | Zip with function |

### lof package

| Function | Signature | Purpose |
|----------|-----------|---------|
| `StringLen` | `StringLen(string) int` | Wrap `len` for strings |
| `Len` | `Len[T]([]T) int` | Wrap `len` for slices |
| `Println` | `Println(string)` | Wrap `fmt.Println` |

---

## 23. Connection to Khorikov (Testing)

FP and good testing are natural allies:

| FP Principle | Testing Benefit |
|--------------|-----------------|
| **Pure functions** | Same input → same output. No mocks needed. |
| **Immutability** | No hidden state changes. Tests are deterministic. |
| **Small functions** | Each testable in isolation |
| **Composition** | Test components, trust the composition |

### Why Pure Functions Are Easy to Test

```go
// Pure function: trivially testable
func average(times []int) float64 {
    sum := slice.Fold(times, 0, func(a, b int) int { return a + b })
    return float64(sum) / float64(len(times))
}

func TestAverage(t *testing.T) {
    tests := []struct {
        input []int
        want  float64
    }{
        {[]int{1, 2, 3}, 2.0},
        {[]int{10}, 10.0},
        {[]int{0, 0, 0}, 0.0},
    }
    for _, tc := range tests {
        got := average(tc.input)
        if got != tc.want {
            t.Errorf("average(%v) = %v, want %v", tc.input, got, tc.want)
        }
    }
}
```

No setup. No teardown. No mocks. The function's entire behavior is determined by its inputs.

### Khorikov's Observable Behavior ↔ FP's Pure Functions

Khorikov says: test *observable behavior*, not implementation details.

FP says: functions are defined by their *input-output relationship*.

These are the same idea. A pure function's observable behavior *is* its input-output relationship. There's nothing else to test.

> If you need mocks, your function probably isn't pure. Consider refactoring to separate pure logic from side effects.

---

## 24. Connection to Ousterhout (Design)

These two perspectives complement each other:

| Tran (FP) | Ousterhout (Design) |
|-----------|---------------------|
| Higher-order functions | Deep modules |
| map/filter/fold | Simple interfaces hiding complexity |
| Composition | Information hiding |
| Immutability | Reducing dependencies |
| Pure functions | Reducing obscurity |

**Key insight:** FP's higher-order functions are naturally "deep"—simple interface (function signature), rich functionality (reusable for many use cases).

```
map: (a → b) → [a] → [b]
```

Two arguments. Works for any transformation on any list. That's a deep interface.

**Composition reduces complexity:**
- Each function does one thing
- Functions compose via standard interfaces (lists, functions)
- No shared mutable state to track

> If Ousterhout's goal is "fighting complexity" and FP's tools are "abstraction and composition," they're attacking the same problem from different angles.
