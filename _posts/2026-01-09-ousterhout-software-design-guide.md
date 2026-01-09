A practical guide to John Ousterhout’s software design principles, extracted from *A
Philosophy of Software Design* (2018). Go-focused examples throughout.

--------------------------------------------------------------------------------------------

Ousterhout’s book changed how I think about code structure. The central idea—that modules
should be deep (simple interface, rich functionality)—is a lens I now apply to every design
decision. This is my distillation of his philosophy into actionable principles.

--------------------------------------------------------------------------------------------

## 1. The Goal: Fighting Complexity

Software design exists to **fight complexity**. Not to follow patterns. Not to maximize
abstraction. Not to minimize lines of code.

> “Complexity is anything related to the structure of a software system that makes it hard
> to understand and modify the system.”

The challenge: as systems grow, complexity accumulates. Each new feature gets harder. Each
bug fix risks introducing more bugs. Eventually, progress grinds to a halt.

**Two strategies for fighting complexity:**

1.  **Eliminate it** — simpler design, fewer special cases, consistent conventions
2.  **Encapsulate it** — hide complexity behind simple interfaces (modular design)

**The trap**: Complexity is incremental. No single decision makes a system complex. It’s the
accumulation of hundreds of small decisions—each one “not a big deal”—that creates an
unmaintainable mess.

> “Complexity isn’t caused by a single catastrophic error; it accumulates in lots of small
> chunks.”

**Zero tolerance is required.** If every developer adds “just a little” complexity, the
system degrades rapidly.

--------------------------------------------------------------------------------------------

## 2. Complexity: Symptoms and Causes

### Three Symptoms of Complexity

| Symptom | Description | Example |
|----|----|----|
| **Change amplification** | Small change requires many code modifications | Changing banner color across 100 pages |
| **Cognitive load** | Developer must know too much to work safely | Function allocates memory that caller must free |
| **Unknown unknowns** | Not obvious what needs to change | Hidden dependency on a message table |

> “Of the three manifestations of complexity, unknown unknowns are the worst.”

Unknown unknowns are insidious because you don’t know what you don’t know. You make a
change, it seems to work, then something breaks in production weeks later.

### Two Root Causes

| Cause            | Description                                       |
|------------------|---------------------------------------------------|
| **Dependencies** | Code can’t be understood or modified in isolation |
| **Obscurity**    | Important information is not obvious              |

Dependencies lead to change amplification and cognitive load. Obscurity creates unknown
unknowns.

**The solution**: Reduce dependencies and make remaining ones obvious. Design so that
developers can work on one piece without understanding the whole system.

--------------------------------------------------------------------------------------------

## 3. Strategic vs Tactical Programming

This is the meta-principle that determines whether your codebase improves or degrades over
time.

### Tactical Programming (Bad)

- Primary goal: get the current task working as quickly as possible
- “I’ll clean it up later” (you won’t)
- Each task adds a little complexity
- Complexity compounds over time

**The tactical tornado**: A developer who pumps out code faster than anyone else, but leaves
destruction in their wake. Management loves them. Engineers who maintain their code hate
them.

### Strategic Programming (Good)

- Primary goal: produce a great design that also works
- Invest 10-20% extra time in design
- Proactive: find the cleanest design, not the first one that works
- Reactive: fix design problems when discovered, don’t patch around them

<!-- -->

    Development Speed
         ^
         │       Strategic ────────────────────►
         │      /
         │     /   Tactical ─────────►
         │    /              \
         │   /                \
         └─────────────────────────────────────► Time

**The payoff comes quickly.** Within months, not years. Strategic investment compounds just
like technical debt—but in your favor.

> “Facebook’s motto was ‘Move fast and break things.’ Eventually, Facebook changed its motto
> to ‘Move fast with solid infrastructure.’”

--------------------------------------------------------------------------------------------

## 4. Deep Modules: The Central Principle ⭐

**This is Ousterhout’s core idea. Everything else flows from it.**

A module is any unit of code with an interface and implementation: a class, a function, a
service, a subsystem.

### The Deep vs Shallow Distinction

            Interface (cost)
        ┌─────────────────────┐
        │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│ ← Wide interface = high cost
        ├─────────────────────┤
        │                     │
        │   Implementation    │ ← Little functionality
        │     (benefit)       │
        └─────────────────────┘
              SHALLOW (bad)

            Interface (cost)
        ┌───────┐
        │▓▓▓▓▓▓▓│ ← Narrow interface = low cost
        ├───────┤
        │       │
        │       │
        │ Impl  │ ← Rich functionality
        │       │
        │       │
        │       │
        └───────┘
          DEEP (good)

### Cost-Benefit Framing

- **Interface = cost** (complexity imposed on users of the module)
- **Implementation = benefit** (functionality provided)
- **Goal: maximize benefit/cost ratio**

The best modules provide powerful functionality through simple interfaces. They hide
complexity rather than exposing it.

### Go Example — Deep Module (Unix I/O)

``` go
// Unix I/O: 5 functions hide hundreds of thousands of lines
fd, _ := os.Open("/path/to/file")  // Just a path
data := make([]byte, 1024)
n, _ := fd.Read(data)              // Just a buffer
fd.Close()

// Hides: disk blocks, caching, permissions, scheduling,
// device drivers, file systems, concurrent access...
```

This is a deep interface. Simple to use, massive functionality hidden.

### The Perfect Deep Module: Garbage Collection

``` go
// Go's garbage collector has NO interface at all
// You just allocate:
user := &User{Name: "Alice"}
slice := make([]int, 1000)

// No free(), no release(), no reference counting
// The GC works invisibly behind the scenes
```

This is the deepest possible module—it provides significant functionality (memory
management) with *zero* interface cost. Adding GC actually *shrinks* the overall system
interface by eliminating manual memory management.

### Go Example — Shallow Module (Classitis)

``` go
// Java-style: three objects to read a file
fileStream := NewFileInputStream(fileName)
bufferedStream := NewBufferedInputStream(fileStream)
objectStream := NewObjectInputStream(bufferedStream)

// Each layer adds interface cost, minimal benefit
// Buffering should be default, not explicit!
```

**Classitis**: The mistaken belief that “classes are good, so more classes are better.”
Results in many shallow classes that add complexity without hiding it.

### Taking it too far

Don’t create one god class. Deep means simple interface, not “everything in one place.” If a
module does too many unrelated things, split it—but make sure each piece is still deep.

--------------------------------------------------------------------------------------------

## 5. Information Hiding and Leakage

### Information Hiding

The most important technique for creating deep modules.

> “Each module should encapsulate a few pieces of knowledge, which represent design
> decisions. The knowledge is embedded in the module’s implementation but does not appear in
> its interface.”

Examples of information to hide: - Data structures and algorithms - File formats and
protocols - Lower-level details (page sizes, network packet structure) - Higher-level
policies (default configurations)

### Information Leakage

The opposite of information hiding. Same knowledge appears in multiple modules.

| Type | Example | Fix |
|----|----|----|
| **Interface leakage** | Exposing internal data structures | Return copies, use accessor methods |
| **Back-door leakage** | Two classes both know file format | Merge or extract to single class |
| **Temporal decomposition** | FileReader + FileWriter both know format | Combine into single FileHandler |

### Go Example — Leakage

``` go
// BAD: Leaks internal Map structure
func (r *Request) GetParams() map[string]string {
    return r.params  // Caller sees internal representation
}

// GOOD: Hides internal structure
func (r *Request) GetParameter(name string) string { ... }
func (r *Request) GetIntParameter(name string) int { ... }
```

The bad version leaks the implementation (a map). If you change to a different data
structure, all callers break. The good version hides it—you could switch to a slice, a tree,
or anything else.

> “Private != hidden. Getters and setters can leak just as much as public fields.”

### Temporal Decomposition

A common cause of leakage: structuring code around the order operations happen rather than
around information.

``` go
// BAD: Temporal decomposition
type FileReader struct { /* knows file format */ }
type FileModifier struct { /* knows file format */ }
type FileWriter struct { /* knows file format */ }

// GOOD: Information-based decomposition
type FileHandler struct { /* knows file format once */ }
```

### Taking it too far

Don’t hide information that callers genuinely need. If they need it, expose it cleanly in
the interface.

--------------------------------------------------------------------------------------------

## 6. General-Purpose Modules are Deeper

Should you design modules for the specific use case at hand, or for general use?

**Answer: “Somewhat general-purpose.”** Implement only what you need now, but design the
interface to be reusable.

### Questions to Ask

1.  What is the simplest interface that covers all my current needs?
2.  How many situations will this method be used in?
3.  Is this API easy to use for my current needs?

### Go Example

``` go
// SPECIAL-PURPOSE (shallow): Editor text class
func (t *Text) BackspaceAtCursor() { ... }
func (t *Text) DeleteSelection() { ... }
func (t *Text) InsertAtCursor(s string) { ... }
// Many methods, each for one use case

// GENERAL-PURPOSE (deep): Same functionality, simpler interface
func (t *Text) Insert(pos Position, s string) { ... }
func (t *Text) Delete(start, end Position) { ... }
// Backspace = Delete(cursor-1, cursor)
// DeleteSelection = Delete(selStart, selEnd)
```

The general-purpose version has a simpler interface (2 methods vs 3+) and is more flexible.
The UI layer can build any editing operation from these primitives.

--------------------------------------------------------------------------------------------

## 7. Different Layer, Different Abstraction

Each layer in a system should provide a different abstraction. If two layers have similar
abstractions, that’s a red flag.

### Red Flag: Pass-Through Methods

``` go
// BAD: Method just delegates to another with same signature
func (c *Controller) GetUser(id int) (*User, error) {
    return c.service.GetUser(id)  // What value does this add?
}
```

If a method does nothing but call another method with the same signature, one of the layers
is probably unnecessary.

### Red Flag: Pass-Through Variables

``` go
// BAD: Variable threaded through many layers
func A(ctx Context) { B(ctx) }
func B(ctx Context) { C(ctx) }
func C(ctx Context) { D(ctx) }
func D(ctx Context) { /* finally uses ctx */ }
```

**Solutions:** - Store in shared object (if truly shared across module) - Use context object
pattern (Go’s `context.Context`) - Question whether all those layers are necessary

### Decorators

Use sparingly. They often create shallow layers that add interface complexity without much
benefit.

``` go
// SHALLOW: Decorator pattern, each layer adds a little
buffered := NewBufferedWriter(file)
compressed := NewGzipWriter(buffered)
encrypted := NewEncryptedWriter(compressed)
// Caller must know about all three, compose correctly

// DEEP: One module handles the common case
writer := NewSecureWriter(file)  // Buffered + compressed + encrypted by default
// Or with options for rare cases:
writer := NewSecureWriter(file, WithoutCompression())
```

The deep version handles the 90% case with zero configuration. The rare caller who needs
custom behavior can use options—but most callers don’t even know compression exists.

--------------------------------------------------------------------------------------------

## 8. Pull Complexity Downward

> “It is more important for a module to have a simple interface than a simple
> implementation.”

Why? A module is implemented once but used many times. Interface complexity is multiplied
across all users. Implementation complexity is contained.

**Configuration parameters push complexity UP to callers.** Usually bad.

### Go Example

``` go
// BAD: Pushes complexity to caller
func Connect(host string, port int, timeout time.Duration,
    retries int, backoff time.Duration) (*Conn, error)

// GOOD: Pulls complexity down, sensible defaults
func Connect(host string) (*Conn, error)
func ConnectWithOptions(host string, opts Options) (*Conn, error)
```

The first version forces every caller to understand and specify five parameters. The second
provides sensible defaults and only exposes complexity when needed.

### Taking it too far

Don’t hide information that callers genuinely need for correctness. If timing or retry
behavior matters to the caller’s logic, expose it.

--------------------------------------------------------------------------------------------

## 9. Better Together or Better Apart?

When should code be combined? When should it be separated?

### Bring Together If:

- **Information is shared** between pieces
- **Combining simplifies the interface** (fewer concepts to learn)
- **Combining eliminates duplication**

### Go Example — Bring Together

``` go
// BAD: Separate classes, information leakage
type HTTPRequestParser struct { /* knows HTTP format */ }
type HTTPResponseBuilder struct { /* knows HTTP format */ }
type HTTPHeaderValidator struct { /* knows HTTP format */ }

// GOOD: Combined, information hidden once
type HTTPHandler struct {
    // Knows HTTP format in one place
    func ParseRequest(r io.Reader) (*Request, error)
    func WriteResponse(w io.Writer, resp *Response) error
    // Header validation is internal, not exposed
}
```

The separate classes all know the HTTP format—information leakage. Combining them
encapsulates that knowledge and provides a simpler interface.

### Keep Apart If:

- **General-purpose vs special-purpose code** (different rates of change)
- **No information sharing** (independent concepts)
- **Separate concerns** that happen to be used together

### Splitting Methods is NOT Always Better

``` go
// Sometimes one method is clearer than three
func ProcessOrder(order Order) error {
    // Validate, charge, fulfill - all share order context
    // Splitting creates pass-through overhead
}
```

The “one method should do one thing” rule can be taken too far. If steps share information
and are always done together, one method may be cleaner.

--------------------------------------------------------------------------------------------

## 10. Define Errors Out of Existence

> “The best way to handle exceptions is to define APIs so they don’t have exceptions.”

Exceptions add complexity. Every exception is a case the caller must handle. The best APIs
make errors impossible or handle them internally.

### Strategies

| Strategy        | Description                                            |
|-----------------|--------------------------------------------------------|
| **Define away** | Change semantics so the “error” isn’t an error         |
| **Mask**        | Handle and recover in lower layer                      |
| **Aggregate**   | Single handler for multiple error types                |
| **Just crash**  | Unrecoverable errors—don’t pretend you can handle them |

### Go Example — Define Away

``` go
// BAD: Forces caller to handle edge case
func (s String) Substring(start, end int) (string, error) {
    if end > len(s) {
        return "", ErrOutOfBounds
    }
    return s[start:end], nil
}

// GOOD: Defines error out of existence
func (s String) Substring(start, end int) string {
    if end > len(s) { end = len(s) }
    if start > end { return "" }
    return s[start:end]
}
```

The second version never returns an error. Out-of-bounds indices are adjusted automatically.
This is what Java’s `substring` should have done.

### Go Example — Just Crash

``` go
// BAD: Pretending to handle unrecoverable errors
func (s *Server) Start() error {
    cfg, err := loadConfig()
    if err != nil {
        return fmt.Errorf("config error: %w", err)  // Caller can't fix this
    }
    // ...
}

// GOOD: Crash on unrecoverable errors
func (s *Server) Start() {
    cfg, err := loadConfig()
    if err != nil {
        log.Fatalf("cannot start: config error: %v", err)  // Crash immediately
    }
    // Server can now assume valid config everywhere
}
```

If the config is missing or corrupt at startup, no amount of error handling will fix it.
Crashing with a clear message is better than threading an error through 10 layers of code
that can’t do anything useful with it.

### Taking it too far

Don’t mask errors that callers need to know about. If a database write fails and the caller
needs to retry or rollback, don’t hide that.

--------------------------------------------------------------------------------------------

## 11. Design It Twice

Always consider at least two approaches before implementing.

- Compare **interfaces**, not just implementations
- Even if first idea seems obvious, force yourself to generate an alternative
- This is cheap early, expensive later

Different designs have different trade-offs. You can’t evaluate trade-offs if you only have
one option.

### Go Example — Two Interface Designs

``` go
// DESIGN A: Text editor with position-based API
type TextEditor interface {
    Insert(pos int, text string)
    Delete(start, end int)
    GetText() string
}

// DESIGN B: Text editor with cursor-based API
type TextEditor interface {
    MoveCursor(pos int)
    InsertAtCursor(text string)
    DeleteSelection()
    GetText() string
}
```

**Comparing trade-offs:**

| Aspect               | Design A (Position)      | Design B (Cursor)         |
|----------------------|--------------------------|---------------------------|
| Interface simplicity | Simpler (2 edit methods) | More methods              |
| Caller complexity    | Must track positions     | Cursor state managed      |
| Batch operations     | Easy (just positions)    | Awkward (move, act, move) |
| Undo implementation  | Straightforward          | Must track cursor too     |

Design A is deeper—simpler interface, pushes cursor management to caller only when needed.
You can’t see this without generating both options.

--------------------------------------------------------------------------------------------

## 12. Comments: What and Why

### The Four Excuses (All Wrong)

1.  **“Good code is self-documenting”** → Code can’t express rationale, constraints, or
    high-level intent
2.  **“No time”** → Comments save more time than they cost
3.  **“Comments get stale”** → Keep them near code, check diffs
4.  **“All comments are worthless”** → You’ve seen bad comments, not an argument against
    good ones

### What to Comment

| Level              | Purpose           | Focus                                     |
|--------------------|-------------------|-------------------------------------------|
| **Interface**      | What and contract | What it does, not how                     |
| **Implementation** | Why               | Why this approach, not what the code does |
| **Cross-module**   | Design decisions  | Rationale that spans modules              |

### Go Example — Interface vs Implementation

``` go
// INTERFACE COMMENT (what + contract):
// GetUser returns the user with the given ID.
// Returns nil if no user exists with that ID.
// The returned User must not be modified by the caller.
func (s *Store) GetUser(id int) *User

// IMPLEMENTATION COMMENT (why):
func (s *Store) GetUser(id int) *User {
    // Use read lock since writes are rare and we want
    // concurrent reads to not block each other
    s.mu.RLock()
    defer s.mu.RUnlock()
    return s.users[id]
}
```

### Write Comments FIRST

Comments are a design tool, not documentation afterthought.

``` go
// Step 1: Write the interface comment BEFORE implementation
// ProcessOrder validates the order, charges payment, and schedules fulfillment.
// Returns an error if validation fails or payment is declined.
// On success, the order status is updated to "processing".
func (s *OrderService) ProcessOrder(order *Order) error {
    // Step 2: Now implement to match the contract
}
```

> “If the interface comment is hard to write, the interface is probably too complex.”

--------------------------------------------------------------------------------------------

## 13. Naming and Obviousness

### Names Should Be Precise

``` go
// BAD: Generic, creates no image
var count int
var data []byte
var info string

// GOOD: Precise, creates clear image
var activeUserCount int
var requestBody []byte
var errorMessage string
```

A good name tells you what the thing is without reading more code.

### Hard to Name = Design Smell

> “If you find it difficult to come up with a name for a particular variable that is
> precise, intuitive, and not too long, this is a red flag. It suggests that the variable
> may not have a clear definition or purpose.”

This applies to functions, classes, and modules too. If you can’t name it clearly, you
probably don’t understand what it does—or it’s doing too many things.

``` go
// Hard to name = design problem
func processData(d []byte) []byte      // What kind of processing?
func handleStuff(x interface{}) error  // What stuff? What handling?

// Easy to name = clear purpose
func compressWithGzip(data []byte) []byte
func validateUserInput(form FormData) error
```

### Code Should Be Obvious

- **Consistent style** — same patterns everywhere
- **Judicious whitespace** — group related lines
- **Avoid clever tricks** — readable beats clever
- **Event-driven code can obscure flow** — document what triggers what

--------------------------------------------------------------------------------------------

## 14. Performance and Complexity

> “Clean design and high performance are compatible.”

**Key insight**: Simple code tends to be fast code. Complexity adds overhead (more branches,
more indirection, more cognitive load for the optimizer).

### When Optimizing

1.  **Measure first** — intuitions about performance are unreliable
2.  **Design around the critical path** — minimize code executed in common case
3.  **Remove special cases from critical path** — handle them separately

### Go Example

``` go
// BAD: Multiple special case checks on critical path
func (b *Buffer) Alloc(size int) []byte {
    if b.allocations == nil { ... }        // special case 1
    if b.lastChunk == nil { ... }          // special case 2
    if b.lastChunk.remaining < size { ... } // special case 3
    // ... finally allocate
}

// GOOD: Single check guards critical path
func (b *Buffer) Alloc(size int) []byte {
    if b.extraBytes >= size {
        // Fast path: extend last chunk (common case)
        return b.extendLastChunk(size)
    }
    // Slow path: handle all special cases
    return b.allocSlow(size)
}
```

### Deep Modules Help Performance

- Fewer layer crossings = less overhead
- More work per function call = better amortization
- Simple interfaces = less setup/teardown

### Real-World Case: RAMCloud Buffer

Ousterhout’s team optimized RAMCloud’s Buffer class (manages variable-length byte arrays):

**Before:** Three layers of methods, 6 conditional checks on critical path, 1886 lines
**After:** Single method with one fast-path check, 1476 lines

``` go
// BEFORE: 6 checks, 3 method calls on critical path
func (b *Buffer) Alloc(size int) []byte {
    return b.allocateAppend(size)  // layer 1
}
func (b *Buffer) allocateAppend(size int) []byte {
    if b.allocations == nil { ... }
    return b.allocations.allocateAppend(size)  // layer 2
}
func (a *Allocation) allocateAppend(size int) []byte {
    if a.remaining < size { ... }  // layer 3
    // finally allocate
}

// AFTER: 1 check, 1 method on critical path
func (b *Buffer) Alloc(size int) []byte {
    if b.extraBytes >= size {
        // Fast path: common case in 2 lines
        result := b.lastChunk[b.used : b.used+size]
        b.used += size
        return result
    }
    return b.allocSlow(size)  // Rare cases handled separately
}
```

**Result:** 2x speedup (8.8ns → 4.75ns), 20% less code, simpler design.

> “The Buffer class rewrite improved its performance by a factor of 2 while simplifying its
> design and reducing code size by 20%.”

--------------------------------------------------------------------------------------------

## 15. Summary: Design Principles

1.  Complexity is incremental: sweat the small stuff
2.  Working code isn’t enough
3.  Make continual small investments to improve design
4.  **Modules should be deep**
5.  Interfaces should make common case simple
6.  Simple interface \> simple implementation
7.  General-purpose modules are deeper
8.  Separate general-purpose and special-purpose code
9.  Different layers should have different abstractions
10. Pull complexity downward
11. Define errors out of existence
12. Design it twice
13. Comments describe what’s not obvious from code
14. Software should be designed for reading, not writing
15. Increments of development should be abstractions, not features

--------------------------------------------------------------------------------------------

## 16. Summary: Red Flags

| Red Flag                             | Meaning                                             |
|--------------------------------------|-----------------------------------------------------|
| **Shallow module**                   | Interface as complex as implementation              |
| **Information leakage**              | Same knowledge in multiple modules                  |
| **Temporal decomposition**           | Structure based on execution order, not information |
| **Overexposure**                     | API forces learning rarely-used features            |
| **Pass-through method**              | Just delegates to method with similar signature     |
| **Repetition**                       | Same code in multiple places                        |
| **Special-general mixture**          | Not cleanly separated                               |
| **Conjoined methods**                | Can’t understand one without the other              |
| **Comment repeats code**             | No new information                                  |
| **Implementation in interface docs** | Wrong abstraction level                             |
| **Vague name**                       | Doesn’t convey useful information                   |
| **Hard to describe**                 | Needs long documentation (design problem)           |
| **Nonobvious code**                  | Can’t understand easily                             |

--------------------------------------------------------------------------------------------

## 17. Quick Reference for CLAUDE.md

``` markdown
### Software Design: Ousterhout Principles

**Core principle:** Modules should be deep (simple interface, rich functionality).

**Fight complexity by:**
- Eliminating it (simpler design)
- Encapsulating it (information hiding)

**Three symptoms of complexity:**
1. Change amplification - small change → many modifications
2. Cognitive load - must know too much
3. Unknown unknowns - not obvious what to change

**Strategic programming:** Invest 10-20% extra time in design. Pays off within months.

**Key techniques:**
| Technique | Meaning |
|-----------|---------|
| Deep modules | Simple interface hiding complex implementation |
| Information hiding | Encapsulate design decisions within modules |
| Pull complexity down | Better complex implementation than complex interface |
| Define errors away | Design APIs so errors can't happen |
| Design it twice | Always consider alternatives |

**Red flags:**
- Pass-through methods (just delegate)
- Temporal decomposition (structure by execution order)
- Classitis (too many shallow classes)
- Configuration parameters (pushing complexity up)

**Comments:** Describe what's NOT obvious. Write them first (design tool).
```

--------------------------------------------------------------------------------------------

## 18. Connection to Khorikov (Testing)

These two books complement each other:

| Ousterhout (Design)  | Khorikov (Testing)                |
|----------------------|-----------------------------------|
| Deep modules         | Domain layer (unit test)          |
| Shallow modules      | Controllers (integration test)    |
| Information hiding   | Observable behavior only          |
| Pull complexity down | Don’t mock internal collaborators |
| Simple interface     | Simple test setup                 |

**Key insight:** Well-designed code (Ousterhout) is inherently testable (Khorikov).

- Deep modules with clean interfaces → easy to test observable behavior
- Information hiding → tests don’t couple to implementation details
- Defining errors away → fewer error paths to test
- General-purpose modules → reusable test utilities

> If you need mocks for internal collaborators, that’s a design smell. Both authors agree:
> the fix is to redesign, not to reach for more mocks.

--------------------------------------------------------------------------------------------

*Based on Ousterhout, John. “A Philosophy of Software Design.” Yaknyam Press, 2018. ISBN
978-1-7321022-0-0.*
