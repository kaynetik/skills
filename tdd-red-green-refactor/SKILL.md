---
name: tdd-red-green-refactor
description: >-
  Test-driven development using Red-Green-Refactor for bug fixes, new features,
  and regression prevention. Writes a failing test first to prove a defect or
  define behavior, then implements minimal code to pass, then refactors. Use when
  fixing bugs, encountering failing behavior, adding new features, writing tests,
  or when the user mentions TDD, red-green-refactor, regression test, failing
  test, test first, or test-driven.
---

# Test-Driven Development: Red-Green-Refactor

## Core Principle

Tests verify **behavior through public interfaces**, not implementation details.
A test that breaks when you refactor internals -- but behavior is unchanged --
is testing implementation, not behavior. Good tests survive refactors.

When fixing a bug: **prove it exists with a failing test before touching
production code.** The test is evidence. The fix is the response to that evidence.

## Workflow Overview

```
RED   ->  Write a test that fails (proves the bug or defines missing behavior)
GREEN ->  Write the minimum code to make the test pass
REFACTOR -> Improve structure, naming, duplication -- tests stay green
```

One cycle per behavior. Vertical slices, not horizontal.

---

## Phase 1: RED -- Establish Failure

### For Bug Fixes

1. **Reproduce the bug** -- identify the exact input, state, or sequence that
   triggers the defect.
2. **Write a test** that exercises the buggy code path with the offending input.
3. **Assert the correct (expected) behavior**, not the current broken output.
4. **Run the test** -- it must fail. If it passes, your test is not capturing the
   bug. Rethink your assertion or test setup.
5. **Name the test descriptively** -- include the bug/ticket reference if one
   exists (e.g., `test_bug_1234_negative_balance_rejected`).

### For New Features

1. **Define one behavior** the feature should exhibit.
2. **Write a test** for that single behavior using the public API/interface.
3. **Run the test** -- confirm it fails (the feature does not exist yet).

### RED Phase Rules

- The test must fail for the **right reason** (missing behavior, not a compile
  error or import failure).
- If you cannot write a test, that is a design signal: the code is not testable
  enough. Address testability first.
- Do not write multiple tests at once. One test, one behavior.

### Hypothesis-Driven Bug Investigation

When the bug's root cause is unclear:

1. Brainstorm multiple hypotheses about what causes the defect.
2. Prioritize by likelihood and cost to falsify.
3. Write a test targeting the top hypothesis.
4. Timebox investigation -- if a hypothesis does not pan out within the timebox,
   move to the next one.
5. A test that passes unexpectedly is useful data: it eliminates a hypothesis.

---

## Phase 2: GREEN -- Minimal Implementation

1. Write the **smallest, simplest code** that makes the failing test pass.
2. Do not add features, abstractions, or optimizations not required by the test.
3. Do not anticipate future tests -- solve only the current one.
4. Run all tests -- the new test passes and no existing tests broke.

### GREEN Phase Rules

- **Minimal** is enough: ugly code is fine at this stage. Correctness over elegance.
- If an existing test breaks, your change introduced a regression. Fix it before
  proceeding.
- If you find yourself writing significant code, consider whether you skipped a
  smaller intermediate test.

---

## Phase 3: REFACTOR -- Improve Structure

Only enter this phase when **all tests are green**.

1. Look for duplication, unclear naming, or structural issues.
2. Apply one refactoring at a time.
3. Run tests after each change -- they must remain green.
4. Common refactorings at this stage:
   - Extract shared logic into functions/methods
   - Rename for clarity
   - Simplify conditionals
   - Move code to more appropriate modules
   - Deepen modules (smaller public interface, richer implementation)

### REFACTOR Phase Rules

- Never refactor while RED. Get to GREEN first.
- If a refactoring breaks a test, undo and take a smaller step.
- Do not add new behavior during refactoring. That is a new RED phase.
- Refactoring is optional per cycle -- skip if the code is clean enough.

---

## Bug Fix Workflow (Detailed)

This is the primary use case. When encountering a bug:

```
1. UNDERSTAND    ->  Reproduce and isolate the defect
2. RED           ->  Write a test asserting correct behavior (test fails)
3. GREEN         ->  Fix the bug with minimal code (test passes)
4. REFACTOR      ->  Clean up if needed (tests stay green)
5. VERIFY        ->  Run full test suite; confirm no regressions
```

### Separation of Concerns in PRs

For team workflows, consider splitting into two commits or PRs:

**Commit/PR 1 -- Expose the bug:**
- Add the failing test that demonstrates the defect
- Assert the *correct* expected behavior (test will fail)
- This proves the bug is real and reproducible

**Commit/PR 2 -- Fix the bug:**
- Change production code to fix the defect
- The previously failing test now passes
- This proves the fix addresses the exact bug

This separation provides auditable evidence that the test actually catches the
defect, not that it was written after-the-fact to rubberstamp a fix.

---

## Anti-Patterns

### Horizontal Slicing (write all tests, then all code)

Tests written in bulk test *imagined* behavior. You end up testing shapes and
signatures instead of actual behavior. Tests become insensitive to real changes.

```
WRONG:
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT:
  RED->GREEN: test1 -> impl1
  RED->GREEN: test2 -> impl2
  RED->GREEN: test3 -> impl3
```

### Testing Implementation Instead of Behavior

Bad signals:
- Test mocks internal collaborators
- Test accesses private methods or fields
- Test verifies internal state (e.g., querying a database directly instead of
  using the public interface)
- Test breaks when you rename an internal function

### Skipping RED

Writing tests after the implementation ("test-after") does not provide the
design feedback that TDD gives. If the test never failed, you have no proof it
can catch regressions.

### Gold-Plating in GREEN

Adding abstractions, optimizations, or extra features during the GREEN phase.
The GREEN phase is about correctness, not elegance. Save structural improvements
for REFACTOR.

### Refactoring While RED

Changing structure while tests are failing makes it impossible to distinguish
between test failures from the original defect and new failures from your
refactoring.

---

## Per-Cycle Checklist

Use this mental checklist for each RED-GREEN-REFACTOR cycle:

```
[ ] Test describes behavior, not implementation
[ ] Test uses the public interface only
[ ] Test would survive an internal refactor
[ ] Test fails for the right reason (RED)
[ ] Implementation is minimal for this test (GREEN)
[ ] No speculative features added (GREEN)
[ ] All tests pass after refactoring (REFACTOR)
[ ] No new behavior introduced during refactor
```

---

## Language-Specific Guidance

### Rust

- Use `#[test]` and `#[should_panic]` for unit tests
- Place integration tests in `tests/` directory
- Use `cargo test` to run; `cargo test -- --nocapture` for stdout
- Consider `#[cfg(test)] mod tests` for test modules alongside source
- Use `assert_eq!`, `assert_ne!`, `assert!` macros
- For async tests: `#[tokio::test]` with tokio runtime

### Go

- Use `_test.go` file suffix and `func TestXxx(t *testing.T)` signature
- Run with `go test ./...`
- Use `t.Errorf` / `t.Fatalf` for assertions
- Table-driven tests are idiomatic for testing multiple inputs
- Use `t.Run` for subtests

### TypeScript

- Use test frameworks like vitest, jest, or node:test
- Run with the appropriate test runner command
- Use `describe`/`it`/`expect` pattern
- For async: return promises or use `async`/`await` in test functions

### Solidity

- Use Foundry's `forge test` with `function test_*` naming
- Use `assertEq`, `assertTrue`, `vm.expectRevert` for assertions
- Fork tests with `vm.createFork` for mainnet state
- Use `setUp()` for test fixtures
- Fuzz tests: `function testFuzz_*(uint256 x)` for property-based testing

---

## When the Bug is Hard to Test

If writing a test is difficult or the environment lacks test infrastructure:

1. Write a test that fails with an explicit message explaining the bug and why
   testing is hard.
2. Fix the bug.
3. Replace the explicit failure with a proper assertion once testability
   improves.
4. Invest in making the code more testable -- this is a design improvement.

## Additional Resources

- For concrete examples per language, see [references/examples.md](references/examples.md)
