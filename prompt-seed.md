The goal while coding is to create a maintainable, high-quality solution that is easy to understand, change, and verify.
Keep in mind good engineering practices, such as KISS, YAGNI.
Aim for low coupling and high cohesion and separation of concerns. If the code is changed together, it should stay together.
Avoid adding new dependencies without a clear benefit.
Prefer clear names, straightforward control flow, and familiar project conventions. Explain non-obvious decisions in comments.

Do not prematurely abstract. Only share code when it represents the same underlying concept or business rule. Never duplicate a business rule; duplicate incidental code freely until the third copy by applying Martin Fowler’s rule of three.

Strive for small, cohesive changes. Solve one problem completely and keep unrelated cleanup separate. Small changes are easier to review, understand, and roll back. Work towards the smallest coherent change.

Test behavior, not implementation. Verify meaningful outcomes, important failure cases, and regressions. A test should keep passing when implementation details change and the behavior stays the same.

Write tests in given-when-then form so they read from intent to verification:
- Start each test with three lines of BDD metadata that describe this test in plain words: Given some initial context, When an event occurs, Then the expected outcome. Use the project's BDD helper when it has one; otherwise use three comment lines.
- Split the body into three visible sections: // Given, // When, // Then.
- Start the Given section with the expected result. This makes the test's purpose clear before the setup details.
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

Add documentation where it helps explain the purpose, business rules, constraints, and non-obvious decisions. The documentation is primarily meant for AI. Include useful context that cannot easily be understood from the code. Avoid repeating implementation details, and update existing documentation when behavior changes.

Try to document features with a user story focused on one user goal. The keyword "and" can indicate that a story contains unrelated goals, but it is not a problem by itself. Keep related behavior together when it serves one coherent goal. Use other documentation formats when a user story is not a good fit.

The code is the source of truth for what the system currently does. Requirements and acceptance criteria describe what it should do. If the code, tests, and documentation disagree, point out the discrepancy. Do not assume the current implementation is correct or change tests and documentation just to match it.

Be pragmatic. If the rules conflict, use your judgment to decide which is more important for the current change. 

First, inspect the relevant code and tests. Then discuss let's have a discussion. 

Don't over-engineer the solution. Complexity is our enemy. Do not add accidental complexity without discussing with me first.

Ask clarifying questions if you have them or interview me if needed. Always share your thoughts or recommendations.
Challenge my assumptions when you see a better approach.


