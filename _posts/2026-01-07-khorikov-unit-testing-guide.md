---
layout: post
title: "Khorikov Unit Testing Guide"
date: 2026-01-07 12:00:00 -05:00
categories: [ testing, go, software-engineering ]
---

A practical guide to Vladimir Khorikov's unit testing principles, extracted from *Unit Testing: Principles, Practices, and Patterns* (2020). Go-focused examples throughout.

---

I recently read Khorikov's book and found myself returning to the same concepts repeatedly. This is my distillation—the ideas I actually use when writing and reviewing tests.

---

## 1. The Goal: Sustainable Growth

Unit testing exists to **enable sustainable growth of the software project**. Not coverage. Not checking boxes. Not proving you did work.

The challenge: as projects grow, development slows. New features take longer. Bugs multiply. Code becomes fragile. Tests should prevent this decay by:

- Catching regressions before they reach production
- Enabling confident refactoring
- Serving as living documentation

**The trap**: Teams chase coverage metrics, accumulating tests that don't actually help. A project with 90% coverage can still have:
- Tests that break on every refactor (false positives)
- Tests that miss real bugs (false negatives)
- Tests that take too long to run
- Tests no one can understand

**The goal is sustainable growth, not test quantity.**

---

## 2. Four Pillars of a Good Test

Every test can be evaluated on four dimensions:

| Pillar | Description |
|--------|-------------|
| Protection against regressions | Catches bugs when code changes |
| Resistance to refactoring | No false positives when internals change |
| Fast feedback | Quick execution |
| Maintainability | Easy to read and change |

You cannot maximize all four—there are inherent trade-offs. But **resistance to refactoring is non-negotiable**.

### Why Resistance to Refactoring Matters Most

False positives devastate teams. Khorikov tells the "wolf crying" story:

> A test suite with many false positives conditions developers to ignore test failures. "Oh, that test always fails after changes—just re-run it." Soon, real bugs slip through because failures are dismissed. The test suite becomes useless, then abandoned.

**Root cause of false positives**: Tests coupled to implementation details. When tests verify *how* code works rather than *what* it accomplishes, any internal change triggers failures—even when behavior is correct.

The solution: Test observable behavior only.

---

## 3. Observable Behavior vs Implementation Details

This is the core distinction. Get this right and your tests will be valuable. Get it wrong and they'll be a burden.

**Observable behavior** = operations OR state that help clients achieve their goals.

**Everything else** = implementation details.

### Unit of Behavior, Not Unit of Code

A common mistake: treating "unit test" as "test one class." This couples tests to class structure, which is an implementation detail.

> "The number of classes it takes to implement such a unit of behavior is irrelevant."

Khorikov uses the dog analogy:

> Correct: "When I call my dog, he comes to me."
>
> Wrong: "When I call my dog, his front left leg moves first, then his right leg, then..."

The dog's leg movement is an implementation detail. The observable behavior is: dog comes when called.

### Well-Designed API Automatically Improves Tests

The connection between good API design and good tests is direct:

- **Hide implementation details** → Tests can only verify observable behavior (because that's all they can see)
- **Expose minimum public API** → Fewer things to test, less coupling
- **Encapsulate invariants** → Tests verify correct behavior, not internal state

> "Making the API well-designed automatically improves unit tests."

If your tests need to access private fields or mock internal collaborators, that's a sign your API is leaking implementation details.

### Encapsulation Connection

Encapsulation isn't just about hiding data—it's about **protecting against invariant violations**.

When you leak implementation details:
1. Clients can violate invariants → bugs
2. Tests couple to internals → false positives

**Tell-don't-ask**: Bundle data with the functions that operate on it. Don't ask an object for its state, do calculations, then tell it what its new state should be. Tell the object what you want and let it manage its own state.

### Go Example: Testing Result vs Algorithm

```go
// BAD: Testing the algorithm (implementation detail)
func TestCalculateDiscount_UsesCorrectFormula(t *testing.T) {
    // This test verifies HOW the discount is calculated
    customer := Customer{TotalPurchases: 1000}

    // Checking intermediate steps or formula application
    rate := customer.discountRate()  // Exposes internal method
    assert.Equal(t, 0.1, rate)       // Testing implementation

    expected := 100.0 * rate         // Replicating the algorithm
    actual := customer.CalculateDiscount(100.0)
    assert.Equal(t, expected, actual)
}

// GOOD: Testing the result (observable behavior)
func TestCalculateDiscount_GoldCustomer(t *testing.T) {
    // This test verifies WHAT the discount is
    customer := Customer{TotalPurchases: 1000}  // Gold tier

    discount := customer.CalculateDiscount(100.0)

    // We don't care HOW it's calculated, just that it's correct
    assert.Equal(t, 10.0, discount)  // Gold customers get 10% off
}
```

The bad test will break if you change the formula implementation, even if the result stays correct. The good test only breaks if actual behavior changes.

---

## 4. Three Styles of Unit Testing

| Style | Description | Example |
|-------|-------------|---------|
| **Output-based** | Feed input, check return value | `result := Calculate(input)` |
| **State-based** | Check state after operation | `obj.DoSomething(); assert(obj.Field)` |
| **Communication-based** | Verify interactions with collaborators | `mock.AssertCalled("Method")` |

**Output-based produces the highest quality tests** because:
- No coupling to internal state (state-based)
- No coupling to collaborator interactions (communication-based)
- Pure function in, result out

### Go Example: Prefer Output-Based

```go
// OUTPUT-BASED (best): Pure function, check return value
func TestCalculateTotal(t *testing.T) {
    order := Order{
        Items: []Item{
            {Product: "Book", Price: 10.00, Quantity: 2},
            {Product: "Pen", Price: 1.50, Quantity: 5},
        },
    }

    total := CalculateTotal(order)

    assert.Equal(t, 27.50, total)
}

// STATE-BASED (acceptable): Check object state after operation
func TestCart_AddItem(t *testing.T) {
    cart := Cart{}
    item := Item{Product: "Book", Price: 10.00}

    cart = cart.Add(item)  // Value semantics: returns new cart

    assert.Equal(t, 1, cart.ItemCount())
}

// COMMUNICATION-BASED (avoid): Verify mock interactions
func TestOrderService_CallsRepository(t *testing.T) {
    mockRepo := &MockOrderRepository{}
    service := NewOrderService(mockRepo)

    service.PlaceOrder(order)

    mockRepo.AssertCalled(t, "Save", order)  // Testing interaction
}
```

Design your code to enable output-based testing. Push side effects to the boundaries.

---

## 5. The Four Quadrants (What to Test)

```
                    Few Collaborators    Many Collaborators
                    ─────────────────    ──────────────────
High Complexity     Domain/Algorithms    Overcomplicated
or Domain Sig       → UNIT TEST          → REFACTOR

Low Complexity      Trivial              Controllers
                    → DON'T TEST         → INTEGRATION TEST
```

**Key insight**: "Complexity OR domain significance"—only one is required to warrant unit testing.

### Go Examples for Each Quadrant

```go
// DOMAIN/ALGO (unit test): High domain significance, few collaborators
// Business logic that decides pricing rules
func (u User) CalculateDiscount(purchaseAmount float64) float64 {
    if u.Type == CustomerTypeGold {
        return purchaseAmount * 0.10
    }
    if u.Type == CustomerTypeSilver {
        return purchaseAmount * 0.05
    }
    return 0
}

// Test it thoroughly:
func TestUser_CalculateDiscount(t *testing.T) {
    tests := []struct {
        name     string
        userType CustomerType
        amount   float64
        want     float64
    }{
        {"gold customer", CustomerTypeGold, 100.0, 10.0},
        {"silver customer", CustomerTypeSilver, 100.0, 5.0},
        {"regular customer", CustomerTypeRegular, 100.0, 0.0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            u := User{Type: tt.userType}
            assert.Equal(t, tt.want, u.CalculateDiscount(tt.amount))
        })
    }
}
```

```go
// TRIVIAL (don't test): Low complexity, low significance
// Simple getter—no logic, no business rules
func (u User) Email() string { return u.email }

// Don't waste time testing this
```

```go
// CONTROLLER (integration test): Low complexity, many collaborators
// Orchestrates other components—no complex logic itself
func (c UserController) ChangeEmail(userID int, newEmail string) error {
    user, err := c.userRepo.GetByID(userID)      // collaborator
    if err != nil {
        return err
    }
    company, err := c.companyRepo.Get()          // collaborator
    if err != nil {
        return err
    }
    user = user.ChangeEmail(newEmail, company)   // domain logic (value semantics)
    return c.userRepo.Save(user)                 // collaborator
}

// Integration test this—verify it correctly wires components together
```

```go
// OVERCOMPLICATED (refactor!): High complexity + many collaborators
// This function is trying to do too much
func ProcessOrder(orderID string, db Database, paymentAPI PaymentGateway,
    emailService EmailGateway, inventory InventoryService) error {
    // 50 lines of validation logic
    // payment processing rules
    // inventory checks
    // email notifications
    // database updates
}

// Split into: domain logic (deep) + controller (wide)
```

---

## 6. Mocks: When OK vs Design Smell

### Classical vs London Schools

| School | Approach | Unit Definition |
|--------|----------|-----------------|
| **London (mockist)** | Mock all collaborators | Single class |
| **Classical** | Use real collaborators | Unit of behavior |

**Khorikov sides with classical.** The London school couples tests to class structure, which is an implementation detail.

### Two Types of Communication

| Type | Definition | Mock? |
|------|------------|-------|
| **Intra-system** | Between classes inside your application | No—implementation detail |
| **Inter-system** | Between your application and external systems | Yes—observable behavior |

### When Mocks Are OK: External Boundaries

Mock only **inter-system communications**—interactions with the external world:

- Email gateway
- Payment processor
- External APIs
- Message queues

These are observable behavior of your system as a whole. The outside world can see that you sent an email.

### When Mocks Are a Design Smell: Internal Collaborators

If you need mocks for **intra-system communications**, that's a code smell:

> "Instead of finding ways to test a large, complicated graph of interconnected classes, you should focus on not having such a graph in the first place."

> "The use of mocks only hides this problem; it doesn't tackle the root cause."

**The fix is to redesign**, not to reach for mocks.

### Go Example

```go
// OK: Mocking external email service
// This is inter-system communication—observable to outside world
func TestOrderProcessor_SendsConfirmationEmail(t *testing.T) {
    mockGateway := &SpyEmailGateway{}
    processor := OrderProcessor{EmailGateway: mockGateway}

    processor.CompleteOrder(order)

    assert.True(t, mockGateway.SendCalled)
    assert.Equal(t, order.CustomerEmail, mockGateway.LastRecipient)
}

// SMELL: Mocking internal repository
// If you need this, your domain logic is too coupled to infrastructure
func TestOrderService_MocksRepository(t *testing.T) {
    mockRepo := &MockOrderRepository{}  // ← Design smell
    mockRepo.On("FindByID", "123").Return(order)
    service := OrderService{Repo: mockRepo}

    result := service.GetOrderTotal("123")

    mockRepo.AssertCalled(t, "FindByID", "123")
}

// BETTER: Refactor so domain logic doesn't need repository
func TestCalculateOrderTotal(t *testing.T) {
    order := Order{Items: []Item{%raw%}{{Price: 10}, {Price: 20}}{%endraw%}}

    total := order.CalculateTotal()  // Pure function, value receiver

    assert.Equal(t, 30.0, total)
}
```

---

## 7. Architecture for Testability

### Hexagonal Architecture

```
┌─────────────────────────────────────────┐
│           Application Service           │  ← Integration test
│         (Controller/Orchestrator)       │
├─────────────────────────────────────────┤
│              Domain Layer               │  ← Unit test
│     (Business logic, algorithms)        │
├─────────────────────────────────────────┤
│           Infrastructure                │
│    (DB, APIs, file system, etc.)        │
└─────────────────────────────────────────┘
```

- **Domain layer**: Pure business logic, no external dependencies → unit test
- **Application services**: Orchestration, talks to external world → integration test
- **Only mock at the boundary** between your system and external systems

### Humble Object Pattern

When code has both high complexity AND many collaborators (the "overcomplicated" quadrant), split it:

- **Deep code**: Complex logic, few/no collaborators → unit test
- **Wide code**: Simple orchestration, many collaborators → integration test

> "Code depth vs code width—never both."

### Go Example

```go
// DEEP: User.ChangeEmail - domain logic, few collaborators
// Complex business rules, but no external dependencies
// Uses value semantics: returns modified copy
func (u User) ChangeEmail(newEmail string, company Company) User {
    if company.IsEmailCorporate(newEmail) {
        u.Type = CustomerTypeEmployee
    } else if u.Type == CustomerTypeEmployee {
        u.Type = CustomerTypeRegular
    }
    u.Email = newEmail
    return u
}

// Unit test this exhaustively—it's your domain logic

// WIDE: UserController.ChangeEmail - orchestration, many collaborators
// Simple coordination, talks to database and message bus
func (c UserController) ChangeEmail(userID int, newEmail string) error {
    user, _ := c.userRepo.GetByID(userID)        // collaborator: database
    company, _ := c.companyRepo.Get()            // collaborator: database
    user = user.ChangeEmail(newEmail, company)   // domain logic (tested separately)
    c.userRepo.Save(user)                        // collaborator: database
    c.messageBus.Send("email_changed", user.ID)  // collaborator: message bus
    return nil
}

// Integration test this—one happy path + critical error cases
```

---

## 8. Fractal Nature of Tests

Tests at different layers verify **the same behavior at different granularities**.

- Domain class test: verifies a subgoal
- Application service test: verifies the full use case
- Both trace back to business requirements

**Key insight**: If you can't trace a test to a business requirement, it's probably testing implementation details.

### Go Example

```go
// Domain layer test (subgoal): "corporate emails are identified"
func TestCompany_IsEmailCorporate(t *testing.T) {
    company := Company{Domain: "mycorp.com"}

    assert.True(t, company.IsEmailCorporate("user@mycorp.com"))
    assert.False(t, company.IsEmailCorporate("user@gmail.com"))
}

// Domain layer test (subgoal): "user type changes based on email"
func TestUser_ChangeEmail_UpdatesType(t *testing.T) {
    user := User{Type: CustomerTypeRegular}
    company := Company{Domain: "mycorp.com"}

    user = user.ChangeEmail("new@mycorp.com", company)  // Value semantics

    assert.Equal(t, CustomerTypeEmployee, user.Type)
}

// Application layer test (full use case): "user email is changed"
func TestUserController_ChangeEmail(t *testing.T) {
    // Setup: real database with test data
    db := createTestDatabase(t)
    db.InsertUser(User{ID: 1, Email: "old@gmail.com", Type: CustomerTypeRegular})
    db.InsertCompany(Company{Domain: "mycorp.com"})

    controller := UserController{UserRepo: db, CompanyRepo: db}

    // Act
    err := controller.ChangeEmail(1, "new@mycorp.com")

    // Assert: user updated correctly
    require.NoError(t, err)
    user := db.GetUserByID(1)
    assert.Equal(t, "new@mycorp.com", user.Email)
    assert.Equal(t, CustomerTypeEmployee, user.Type)
}
```

All three tests verify aspects of the same business requirement: "change user email." They test it at different granularities.

---

## 9. The Two-Phase Workflow

### Development (TDD)

During development, tests guide design:

1. **Red**: Write a failing test
2. **Green**: Make it pass (minimal code)
3. **Refactor**: Clean up

At this stage, write tests for everything. Tests help you think through the design. Some of these tests will be scaffolding.

### Pre-PR (Khorikov Rebalancing)

Before merging, reassess your test portfolio with Khorikov's lens:

| Quadrant | TDD Produced | Khorikov Action |
|----------|--------------|-----------------|
| Trivial | Unit tests | **Delete** |
| Domain/Algo | Unit tests | **Keep** |
| Controllers | Unit tests | **Replace** with integration tests |

**This is not a subset—it's a rebalancing.**

Khorikov may also reveal tests to **add** that TDD didn't produce:
- Integration tests for controller happy paths
- Edge cases only visible at system boundaries

### Why Two Phases?

- **TDD targets local development**: Fast feedback, design exploration
- **Khorikov targets CI**: Tests that provide value over time, don't break on refactors

A test valuable during development (helped you think) may be harmful in CI (breaks on every refactor, tests implementation details).

---

## 10. Coverage Metrics

Coverage is a **negative indicator**, not a positive one.

> "Low coverage numbers—say, below 60%—are a certain sign of trouble. They mean there's a lot of untested code in your code base. But high numbers don't mean anything."

**Never make coverage a target.** When coverage is a goal:
- Teams write tests for trivial code
- Tests verify implementation details (easy coverage)
- Valuable edge cases are ignored (hard to cover)

High coverage with low-quality tests is worse than moderate coverage with good tests.

---

## 11. Integration Tests for Controllers

Controllers (application services) should be tested with integration tests:

- **One happy path**: Verify components wire together correctly
- **Edge cases unit tests can't cover**: Boundary conditions, error paths

Don't over-test controllers. They should be "humble"—minimal logic, just coordination. If a controller needs extensive testing, it probably has too much logic (move it to domain layer).

### Go Example

```go
func TestUserController_ChangeEmail_Integration(t *testing.T) {
    // Happy path: email changes correctly
    t.Run("changes email from non-corporate to corporate", func(t *testing.T) {
        db := createTestDatabase(t)
        messageBus := &SpyMessageBus{}
        db.InsertUser(User{ID: 1, Email: "user@gmail.com", Type: CustomerTypeRegular})
        db.InsertCompany(Company{Domain: "mycorp.com"})
        controller := UserController{UserRepo: db, CompanyRepo: db, MessageBus: messageBus}

        err := controller.ChangeEmail(1, "user@mycorp.com")

        require.NoError(t, err)
        user := db.GetUserByID(1)
        assert.Equal(t, "user@mycorp.com", user.Email)
        assert.Equal(t, CustomerTypeEmployee, user.Type)
        assert.True(t, messageBus.SentEmailChanged)
    })

    // Edge case: user doesn't exist
    t.Run("returns error for unknown user", func(t *testing.T) {
        db := createTestDatabase(t)
        controller := UserController{UserRepo: db, CompanyRepo: db}

        err := controller.ChangeEmail(999, "new@example.com")

        assert.Error(t, err)
    })
}
```

---

## 12. Quick Reference

A condensed version for team wikis, PR templates, or coding guidelines.

---

### Testing: Two-Phase Workflow

**Development (TDD):** Write tests first—red/green/refactor. Tests guide design.

**Pre-PR (Khorikov):** Rebalance test portfolio. Not a subset—a reassessment.

| Quadrant | TDD Produced | Khorikov Action |
|----------|--------------|-----------------|
| Trivial | Unit tests | Delete |
| Domain/Algo | Unit tests | Keep |
| Controllers | Unit tests | Replace with integration |

### Four Pillars of a Good Test

| Pillar | Priority |
|--------|----------|
| Protection against regressions | Required |
| **Resistance to refactoring** | **MOST IMPORTANT** |
| Fast feedback | Required |
| Maintainability | Required |

### What to Test (Four Quadrants)

```
                    Few Collaborators    Many Collaborators
                    ─────────────────    ──────────────────
High Complexity     Domain/Algorithms    Overcomplicated
or Domain Sig       → UNIT TEST          → REFACTOR

Low Complexity      Trivial              Controllers
                    → DON'T TEST         → INTEGRATION TEST
```

### Mocks

| Communication | Mock? |
|---------------|-------|
| **Inter-system** (external APIs, email, payment) | Yes—observable behavior |
| **Intra-system** (between your classes) | No—fix design instead |

Needing internal mocks = code architecture problem

### Observable Behavior Only

Test **what** code does, not **how** it does it:
- Observable = operations OR state that help clients achieve goals
- Test the result, not the algorithm
- If you can't trace a test to a business requirement, delete it

### Coverage

- Below 60%: Certain sign of trouble
- High numbers: Mean nothing about quality
- Never make coverage a target

---

*Based on Khorikov, Vladimir. "Unit Testing: Principles, Practices, and Patterns." Manning, 2020. ISBN 978-1617296277.*
