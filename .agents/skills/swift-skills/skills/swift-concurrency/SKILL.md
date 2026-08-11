---
name: swift-concurrency
description: >-
  Use when writing or fixing Swift async/await code, actors, Task/TaskGroup,
  @MainActor, Sendable conformance, AsyncSequence/AsyncStream, checked
  continuations, or resolving Swift 6 strict concurrency (data-race safety)
  compiler errors and warnings.
---

Build and fix Swift 6.3 concurrent code — async/await, actors, tasks, and async sequences — that compiles cleanly under Swift 6 strict concurrency checking.

## Use this skill when

- Writing `async`/`await` functions, `async let`, or `TaskGroup`/`withThrowingTaskGroup` structured concurrency.
- Creating unstructured work with `Task { }`, setting priorities, or handling cancellation.
- Defining or isolating state with `actor`, `@MainActor`, or global actors.
- Fixing `Sendable` conformance errors, `sending` parameter diagnostics, or any Swift 6 data-race-safety compiler error.
- Building custom async iteration with `AsyncSequence`, `AsyncStream`, or `AsyncThrowingStream`.
- Bridging a callback- or delegate-based API into async/await with `withCheckedContinuation`/`withCheckedThrowingContinuation`.
- Asked about Swift 6.3's Task Stealers primitive or cooperative-thread-pool scheduling behavior.

## Do not use this skill when

- Writing basic syntax, types, or protocols with no concurrency involved — use swift-fundamentals or swift-types-generics.
- Handling thrown errors unrelated to concurrency — use swift-error-handling.
- Managing memory/ownership (`ARC`, `weak`/`unowned`, retain cycles) with no actor or task involved — use swift-memory-safety.
- Writing macros or reflection/metaprogramming code — use swift-macros-metaprogramming.
- Writing unit tests or benchmarks for concurrent code — use swift-testing-tooling for the test structure itself; come back here only for the concurrency logic under test.
- Calling into C/Objective-C/other-language APIs — use swift-interop, then return here if the bridged result needs async wrapping.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below.
2. Default to structured concurrency (`async let`, `TaskGroup`) over unstructured `Task { }`; only use unstructured tasks when the work must outlive the calling scope.
3. If the task touches UI or shared state, isolate it: annotate UI-facing types/methods `@MainActor`, and wrap other shared mutable state in an `actor` rather than adding locks or `@unchecked Sendable`.
4. When the compiler reports a strict concurrency error, fix the underlying data-race cause shown in the reference file (isolate the state, mark the type `Sendable`, or use `sending`) — do not silence it.
5. If bridging a non-async API, use a checked continuation and confirm it resumes exactly once on every path (success, failure, cancellation).
6. Re-read the changed code once and confirm it compiles under Swift 6 language mode with no added suppressions.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not add `@unchecked Sendable` or `@preconcurrency` to silence a warning without first trying the structural fix shown in the reference file.
- Do not wrap a continuation-resume in a retry loop; a continuation must resume exactly once — fix the call site instead of looping.
- Stop as soon as the requested feature compiles under strict concurrency.

## Reference files

- `references/async-await-structured-concurrency.md` — open when writing async functions, `async let`, `TaskGroup`, unstructured `Task { }`, priorities, or cancellation.
- `references/actors-sendable-strict-concurrency.md` — open when defining actors, `@MainActor`, fixing `Sendable`/`sending` errors, or resolving Swift 6 strict concurrency diagnostics.
- `references/async-sequences-continuations.md` — open when building `AsyncSequence`/`AsyncStream`/`AsyncThrowingStream` or bridging callback APIs with checked continuations.
