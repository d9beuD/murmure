---
name: swift-error-handling
description: >-
  Use when writing or reviewing Swift error handling — do/try/catch blocks,
  throwing functions (throws), typed throws (throws(SpecificError)), custom
  Error enums, LocalizedError messages, Result<Success, Failure>, rethrows,
  defer cleanup, try?/try!, or retry logic across a call chain.
---

Build correct, exhaustive Swift 6.3 error handling — typed throws, custom Error types, Result, and defer cleanup — that propagates or handles failures without swallowing them.

## Use this skill when

- Writing a function that can fail and deciding between `throws`, `throws(SpecificError)`, and returning `Result<Success, Failure>`.
- Defining a custom `Error` type (enum with associated values) and optionally conforming it to `LocalizedError`.
- Wiring up `do`/`try`/`catch` with multiple `catch` clauses matching specific error cases.
- Converting between throwing functions and `Result` (`Result(catching:)`, `.get()`, `try await`/`try` bridging).
- Adding `defer` blocks for guaranteed cleanup (closing files, unlocking, logging) regardless of how a scope exits.
- Writing a `rethrows` function that forwards a closure's error without adding its own.
- Deciding when `try?` or `try!` is acceptable versus when it hides bugs.
- Implementing a bounded retry loop around a throwing operation.

## Do not use this skill when

- Handling cancellation or errors that only arise from async/Task code — use swift-concurrency (note: throwing async functions still belong here for the throw/catch mechanics).
- Defining the struct/enum/protocol shape itself unrelated to error handling (generic constraints, associated types) — use swift-types-generics.
- Debugging with breakpoints, writing unit tests for error paths, or using `#expect(throws:)` in Swift Testing — use swift-testing-tooling.
- The failure is a crash-worthy programmer error (force-unwrap of a genuinely-invariant value, `precondition`, `fatalError`) rather than a recoverable condition — that is a correctness/fundamentals concern, not error propagation.
- Bridging Objective-C `NSError` domains or C error codes at an FFI boundary — use swift-interop for the boundary shape, then return here for the Swift-side `throws` mapping.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below.
2. Define a dedicated `Error` enum (with associated values for context) instead of throwing `String`, `NSError`, or a generic type.
3. Prefer typed throws (`throws(MyError)`) when the call site needs to exhaustively `switch` on error cases without an `default`/`catch` fallback; use untyped `throws` when callers only need `catch let error as MyError` or mix multiple error types.
4. Add `LocalizedError` conformance only if the error message is user-facing.
5. Use `defer` for any cleanup that must run on every exit path (success, throw, or early `return`), placed immediately after acquiring the resource.
6. Propagate by default (`try` + function marked `throws`); only add a `do`/`catch` where the error can actually be handled or translated — never leave an empty `catch {}`.
7. Use `Result` only when the failure must be stored, passed as a value, or returned from a non-throwing context (e.g. a completion handler); otherwise prefer plain `throws`.
8. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not swallow errors with empty catch blocks.
- Do not wrap every call in `try?` to silence the compiler — decide propagate vs. handle explicitly.
- Stop as soon as the requested feature works and errors are handled or propagated correctly.

## Reference files

- `references/throwing-typed-errors.md` — open when defining custom `Error` types, choosing `throws` vs `throws(SpecificError)`, writing `do`/`catch`/`rethrows`, or deciding on `try?`/`try!`.
- `references/result-defer-patterns.md` — open when working with `Result<Success, Failure>`, converting between `Result` and throwing functions, writing `defer` cleanup, or building a retry loop.
