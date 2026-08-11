---
name: swift-testing-tooling
description: >-
  Use when writing or fixing Swift tests with the Swift Testing framework
  (@Test, @Suite, #expect, #require, parameterized tests, traits/tags,
  .disabled(), .timeLimit(), async tests, test cancellation, warning issues),
  structuring or editing Package.swift and SPM targets/products/dependencies/
  resources/plugins, running swift build/swift test/swift run or opting into
  the Swift Build preview engine, or writing DocC ///  doc comments and
  generating documentation with swift package generate-documentation.
---

Build and run Swift 6.3 test suites with Swift Testing, structure Swift packages with SPM, and write DocC documentation comments.

## Use this skill when

- Writing a new test with `@Test`/`@Suite`, checking values with `#expect`/`#require`, or converting an XCTest suite to Swift Testing.
- Parameterizing a test with `arguments:`, applying traits/tags, `.disabled()`, `.timeLimit()`, or writing an `async`/`throws` test.
- Using Swift 6.3's test cancellation (`Test.cancel()`), warning issues (`Issue.record(_:severity:)`), or attaching an image/data via `Attachment`.
- Creating or editing `Package.swift` — targets, products, dependencies, resources, or plugins.
- Running `swift build`, `swift test`, or `swift run`, or opting into the Swift 6.3 Swift Build preview engine (`--build-system swiftbuild`).
- Writing `///` doc comments (`- Parameter`, `- Returns`, `- Throws`) or generating docs with `swift package generate-documentation`.

## Do not use this skill when

- Writing the production code under test (language mechanics) — use the matching swift-* skill for that domain, then come back here to test it.
- Fixing a concurrency data race surfaced by an async test — use swift-concurrency for the isolation fix itself, then return here to finish the test.
- Writing error types or `throws` propagation logic outside of test assertions — use swift-error-handling.
- Calling into C/Objective-C from a package target — use swift-interop for the interop layer; use this skill only for the package/target wiring around it.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested feature works.

1. Identify the task type and open EXACTLY ONE reference file from the list below.
2. For new test targets or new test files, prefer Swift Testing (`import Testing`) over XCTest; only touch XCTest when editing an existing XCTest suite in place.
3. Prefer `#expect` (non-fatal, keeps checking) over `#require` (fatal unwrap) — reach for `#require` only when a later line depends on the unwrapped value.
4. Keep `Package.swift` minimal and explicit: declare only the targets/products/dependencies the task needs, at the lowest platform/tools version that supports the feature in use.
5. When documenting a public API, add `///` doc comments with `- Parameter`/`- Returns`/`- Throws` only where the signature isn't self-evident.
6. Run `swift test` (or `swift build`) for the requested change and read the failure output before editing again.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not rewrite a passing test suite; only add/adjust the specific test requested.
- Do not retry a flaky test by looping `swift test`; fix the async/ordering cause shown in the reference file instead.
- Stop as soon as `swift test`/`swift build` succeeds for the requested change.

## Reference files

- `references/swift-testing.md` — open when writing/fixing `@Test`/`@Suite` tests, `#expect`/`#require`, parameterized tests, traits/tags, timeouts, async tests, cancellation, or attachments.
- `references/spm-swift-build.md` — open when editing `Package.swift`, wiring targets/products/dependencies/resources/plugins, or running `swift build`/`swift test`/`swift run`/the Swift Build preview engine.
- `references/docc-documentation.md` — open when writing `///` doc comments or generating/publishing DocC documentation.
