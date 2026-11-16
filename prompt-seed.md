These are my engineering practices and the way I like to work. A project's own instructions win where they disagree with these.

## Engineering principles

The goal while coding is to create a maintainable, high-quality solution that is easy to understand, change, and verify.
The purpose of code is to explain to other developers and agents what we want the computer to do. 

If the project states its why (usually in the README), read it first. Every change should serve it.

Keep in mind good engineering practices, such as KISS, YAGNI.
Aim for low coupling and high cohesion and separation of concerns. If the code is changed together, it should stay together. Group code by feature, not by technical role.
Avoid adding new dependencies without a clear benefit.
Prefer clear names, straightforward control flow, and familiar project conventions. Explain non-obvious decisions in comments.

Don't over-engineer the solution. Complexity is our enemy. Do not add accidental complexity without discussing with me first.

Be pragmatic. If the rules conflict, use your judgment to decide which is more important for the current change. 

### Abstraction and duplication

Do not prematurely abstract. Only share code when it represents the same underlying concept or business rule. Never duplicate a business rule; duplicate incidental code freely until the third copy by applying Martin Fowler’s rule of three.

### Avoid primitive obsession

Give domain concepts their own types instead of passing raw strings and numbers around. A named type lets the compiler catch mixed-up arguments, gives the concept a home for its rules, and makes signatures read like the domain. Parse and validate at the boundary (a request, a file, a database row) and pass the typed value inward. Use a named type when a value has rules or is easily confused with another value of the same primitive type; do not wrap values that are just data.

### Small changes

Strive for small, cohesive changes. Solve one problem completely and keep unrelated cleanup separate. Small changes are easier to review, understand, and roll back. Work towards the smallest coherent change.

A feature follows three steps (Kent Beck's tidy first):

1. Tidy first. Look at the code the feature will touch. If a refactor makes the feature easier to add, do that first, without changing behavior.
2. Add the feature. The behavior change, with its tests.
3. Refactor. Clean up what adding the feature revealed, again without changing behavior.

Keep structural changes and behavior changes in separate commits, so each can be reviewed on its own terms. Skip a step that is not needed.

## Testing

Test behavior, not implementation. Verify meaningful outcomes, important failure cases, and regressions. A test should keep passing when implementation details change and the behavior stays the same.
Tests exist to let agents change the code safely, not to reach a coverage number.

Prefer test-driven development (TDD) or behavior-driven development (BDD) whenever possible. Write the test for the next behavior first, see it fail for the right reason, write the simplest code that makes it pass, then refactor while the tests stay green. With BDD, start from the user story: each acceptance criterion becomes a given-when-then test. When test-first is not practical, such as in a throwaway spike or while exploring how something should look or feel, say so, and write the tests as soon as the behavior settles.

Write tests in given-when-then form so they read from intent to verification:
- Start each test with three lines of BDD metadata that describe this test in plain words: Given some initial context, When an event occurs, Then the expected outcome. Use the project's BDD helper when it has one; otherwise use three comment lines.
- Split the body into three visible sections: // Given, // When, // Then.
- Start the Given section with the expected result. This makes the test's purpose clear before the setup details. When the outcome is not a single value, name what you expect anyway (`expectedHeadings`, `maximumDifference`) and put it first.
- Keep each test to one behavior and give it a specific name. Split creation, idempotency, validation, and error cases into separate tests.
- Move noisy setup and repeated assertions into local test helpers when that makes the test read like behavior.

Adapt the syntax to the project's language and test framework.

Example:

// Given a customer with no orders.
// When their order summary is requested.
// Then an empty summary is returned.
test "order summary: no orders gives an empty summary" {
    // Given
    expected = emptyOrderSummary()
    customer = createCustomer()

    // When
    actual = summaryFor(customer)

    // Then
    assertEqual(actual, expected)
}

## Checking your work

Run the project's checks (format, lint, tests) before you call a change done. If the project has no single command for them, say so.

When a change can be seen or heard, look at the result instead of assuming it. Compare screenshots before and after a UI change; for a pure refactor they should be identical. If you have no way to see the result of your work, tell me and propose the simplest tool that would let you (a screenshot command, a log, a recorded sample).

## Comments and documentation

Add documentation where it helps explain the purpose, business rules, constraints, and non-obvious decisions. The documentation is primarily meant for AI. Include useful context that cannot easily be understood from the code. Avoid repeating implementation details, and update existing documentation when behavior changes.

Try to document features with a user story focused on one user goal. The keyword "and" can indicate that a story contains unrelated goals, but it is not a problem by itself. Keep related behavior together when it serves one coherent goal. Use other documentation formats when a user story is not a good fit.

The code is the source of truth for what the system currently does. Requirements and acceptance criteria describe what it should do. If the code, tests, and documentation disagree, point out the discrepancy. Do not assume the current implementation is correct or change tests and documentation just to match it.

## Working with me

When a task involves a design choice (a new feature, a change of structure, a trade-off), first inspect the relevant code and tests, then discuss it with me before building. For a small, well-understood change, make it and tell me what you did.

In a discussion, ask one question at a time and keep the conversation natural. Ask clarifying questions if you have them or interview me if needed. Always share your thoughts or recommendations.
Challenge my assumptions when you see a better approach.
