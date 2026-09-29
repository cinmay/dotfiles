The goal while coding is to create a maintainable, high-quality solution that is easy to understand, change, and verify.
Keep in mind good engineering practices, such as KISS, YAGNI.
Aim for low coupling and high cohesion and separation of concerns. If the code is changed together, it should stay together.
Avoid adding new dependencies without a clear benefit.
Prefer clear names, straightforward control flow, and familiar project conventions. Explain non-obvious decisions in comments.
Do not prematurely abstract. Only share code when it represents the same underlying concept or business rule. Avoid duplicating business logic or behavior.
Otherwise apply Martin Fowler’s rule of three: “When you have three instances of the same thing, it is time to abstract.”

Strive for small, cohesive changes. Solve one problem completely and keep unrelated cleanup separate. Small changes are easier to review, understand, and roll back. Work towards the smallest coherent change.

Test behavior, not implementation. Verify meaningful outcomes, important failure cases, and regressions. Test should survive to work and survive internal changes when implementation details change, but the behavior remains the same. Using BDD's given-when-then format is encouraged. The tests should start with three commented lines: Given, When, Then.

The test should also be split into three sections: given , when, then. Try to always start the given section with the expected outcome first. Test should focus on outcome. 

Example:
// given: the expected outcome
// when: the action that triggers the behavior
// then: the expected result of the action

// Given:

var expectedOutcome = "some expected outcome";

// when

var outcome = someFunctionThatTriggersBehavior();

// then
assert.equal(outcome, expectedOutcome);
Add documentation where it helps explain the purpose, business rules, constraints, and non-obvious decisions. The documentation is primarily meant for AI. Include useful context that cannot easily be understood from the code. Avoid repeating implementation details, and update existing documentation when behavior changes.

Try to document features with a user story focused on one user goal. The keyword "and" can indicate that a story contains unrelated goals, but it is not a problem by itself. Keep related behavior together when it serves one coherent goal. Use other documentation formats when a user story is not a good fit.

The code is the source of truth for what the system currently does. Requirements and acceptance criteria describe what it should do. If the code, tests, and documentation disagree, point out the discrepancy. Do not assume the current implementation is correct or change tests and documentation just to match it.

Be pragmatic. If the rules conflict, use your judgment to decide which is more important for the current change. 

First, inspect the relevant code and tests. Then discuss let's have a discussion. 

Don't over-engineer the solution. Complexity is our enemy. Do not add accidental complexity without discussing with me first.

Ask clarifying questions if you have them or interview me if needed. Always share your thoughts or recommendations.
Challenge my assumptions when you see a better approach.


