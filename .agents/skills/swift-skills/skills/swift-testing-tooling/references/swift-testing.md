# Swift Testing Framework

## Basic tests with `@Test` and `#expect`

`@Test` marks a function (top-level or in a type) as a test; it can be `async` and/or `throws` with no extra ceremony. `#expect` checks a condition, records a failure with full expression detail on mismatch, and keeps executing the rest of the test.

```swift
import Testing

@Test func additionIsCommutative() {
    #expect(2 + 3 == 3 + 2)
}

@Test func fetchesUser() async throws {
    let user = try await UserService.fetch(id: 1)
    #expect(user.name == "Ada")
    #expect(user.age > 0)
}
```

## `#require` for fatal unwraps

`#require` behaves like `#expect` but throws and stops the test immediately on failure — use it when a later line cannot proceed without the value (optional unwrap, non-empty collection, etc.).

```swift
@Test func decodesPayload() throws {
    let data = try #require(payload.data(using: .utf8))
    let model = try JSONDecoder().decode(Model.self, from: data)
    #expect(model.id == 42)
}
```

`#require(throws:)` asserts a specific error is thrown, and `#require(throws: Never.self)` asserts nothing is thrown.

```swift
@Test func rejectsNegativeAmount() {
    #expect(throws: ValidationError.negativeAmount) {
        try validate(amount: -1)
    }
}
```

## Grouping with `@Suite`

`@Suite` groups related tests in a type, optionally sharing setup via `init`/`deinit`; suites can nest and inherit tags/traits from their containing suite.

```swift
@Suite("Account tests")
struct AccountTests {
    let account = Account(balance: 100)

    @Test func withdrawalReducesBalance() throws {
        try account.withdraw(30)
        #expect(account.balance == 70)
    }

    @Test func overdraftThrows() {
        #expect(throws: AccountError.insufficientFunds) {
            try account.withdraw(1000)
        }
    }
}
```

## Parameterized tests with `arguments:`

Pass one or more collections to `arguments:` and Swift Testing runs the test once per element (or per combination, for two collections), reporting each argument set as its own case.

```swift
@Test(arguments: [1, 2, 3, 5, 8])
func isPositive(_ n: Int) {
    #expect(n > 0)
}

@Test(arguments: ["ada", "grace"], [1, 2])
func combinations(name: String, count: Int) {
    #expect(!name.isEmpty)
    #expect(count > 0)
}
```

Use a `zip`ped sequence of tuples instead of the two-collection form when arguments must be paired rather than cross-producted.

```swift
@Test(arguments: zip(["ada", "grace"], [36, 85]))
func nameMatchesAge(name: String, age: Int) {
    #expect(age > 0)
}
```

## Traits: tags, `.disabled()`, `.timeLimit()`

Traits attach metadata or behavior to a test/suite. `.tags(...)` categorizes tests for filtered runs; `.disabled(_:)` skips a test with a reason shown in output; `.timeLimit(...)` fails a test that overruns.

```swift
extension Tag {
    @Tag static var networking: Self
}

@Test(.tags(.networking), .timeLimit(.seconds(5)))
func fetchesWithinTimeLimit() async throws {
    _ = try await Network.fetch()
}

@Test(.disabled("flaky until server fix lands"))
func flakyEndpoint() async throws {
    _ = try await Network.fetch()
}
```

`.enabled(if:)` conditionally runs a test based on a runtime check, which is preferable to disabling it outright when the skip condition is only sometimes true.

```swift
@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
func onlyRunsLocally() { }
```

Run a filtered subset from the command line with `swift test --filter`:

```bash
swift test --filter AccountTests
swift test --filter ".tags(networking)"
```

## Async tests, confirmations, and expected failures

Confirmations bridge callback-based async APIs into a test: `confirmation` returns a closure to call, and the test fails if it isn't called the expected number of times before the enclosing scope exits.

```swift
@Test func notifiesObserversOnce() async {
    await confirmation(expectedCount: 1) { confirm in
        let center = NotificationCenter()
        center.addObserver(forName: .didUpdate, object: nil, queue: nil) { _ in
            confirm()
        }
        center.post(name: .didUpdate, object: nil)
    }
}
```

`withKnownIssue` marks a currently-failing check as a known issue instead of a test failure, so the suite stays green while tracking the bug; it flips to reporting a failure automatically once the underlying check starts passing.

```swift
@Test func rendersCorrectly() {
    withKnownIssue("Layout bug tracked in JIRA-123") {
        #expect(renderedWidth == 200)
    }
}
```

## Swift 6.3: test cancellation and warning issues

`Test.cancel()` (in an `async` test) terminates the current test and its task hierarchy immediately — use it to bail out of a parameterized case early or stop once a runtime precondition makes the rest of the test meaningless.

```swift
@Test(arguments: servers)
func pingsServer(_ server: Server) async throws {
    guard server.isReachable else {
        try Test.cancel()
    }
    #expect(try await server.ping() < .seconds(1))
}
```

`Issue.record(_:severity:)` records a non-fatal warning issue (`severity: .warning`) that shows up in output without failing the test — use it for "this is suspicious but not wrong" observations, reserving `severity: .error` (the default) for real failures.

```swift
@Test func computesEstimate() {
    let estimate = computeEstimate()
    if estimate.confidence < 0.5 {
        Issue.record("Low-confidence estimate: \(estimate.confidence)", severity: .warning)
    }
    #expect(estimate.value > 0)
}
```

## Attaching images and data

`Attachment` captures a value (data, an image, or any `Attachable`-conforming type) alongside a test run for later inspection, without failing the test.

```swift
@Test func rendersExpectedSnapshot() throws {
    let image = try renderSnapshot()
    Attachment.record(image, named: "snapshot")
    #expect(image.size.width > 0)
}
```

## XCTest interop (existing suites only)

Only touch XCTest when editing an existing `XCTestCase` suite in place; do not add new XCTest files. `XCTAssert*` family calls map onto `#expect`/`#require`, and both frameworks can run side by side in one target during a migration.

```swift
import XCTest

final class LegacyAccountTests: XCTestCase {
    func testWithdrawal() throws {
        let account = Account(balance: 100)
        try account.withdraw(30)
        XCTAssertEqual(account.balance, 70)
    }
}
```

## Stop conditions for this file

- Every new assertion uses `#expect`/`#require`, not a new `XCTAssert*` call.
- Parameterized cases use `arguments:` instead of a hand-rolled `for` loop of separate `@Test` calls.
- `swift test` (optionally with `--filter`) passes for the specific test(s) the task asked for.
