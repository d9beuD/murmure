# Throwing Functions and Typed Errors

## Defining a custom Error type

Model failures as an enum with associated values for context; conform to `Error` (a marker protocol with no requirements). This beats throwing `String` or `NSError` because callers can `switch` exhaustively.

```swift
enum ParseError: Error {
    case emptyInput
    case invalidToken(String, line: Int)
    case unexpectedEndOfFile
}
```

## `throws` vs typed `throws(SpecificError)`

Plain `throws` means "throws some `Error`"; callers must `catch` generically or cast. Typed throws (`throws(SpecificError)`, stable since Swift 6) let the compiler know the exact error type, enabling exhaustive `switch` in `catch` without a fallback case and avoiding existential boxing overhead.

```swift
func parse(_ text: String) throws(ParseError) -> [Token] {
    guard !text.isEmpty else { throw ParseError.emptyInput }
    // ... tokenize ...
    return tokens
}

do {
    let tokens = try parse(source)
} catch let error {
    switch error {                 // `error` is ParseError, no default needed
    case .emptyInput: print("nothing to parse")
    case .invalidToken(let tok, let line): print("bad token \(tok) at \(line)")
    case .unexpectedEndOfFile: print("truncated input")
    }
}
```

Use typed throws when the function has one well-defined failure domain and callers benefit from exhaustiveness or avoiding `any Error` allocation on hot paths. Use plain `throws` when a function can propagate multiple unrelated error types (e.g. it calls into several throwing subsystems) — forcing a single typed error there just means wrapping everything in one enum for no real gain.

## `LocalizedError` for user-facing messages

Conform to `LocalizedError` when the error text is shown to a user or logged for support; it adds `errorDescription`, `failureReason`, and `recoverySuggestion` on top of `Error`.

```swift
enum AccountError: LocalizedError {
    case insufficientFunds(shortfall: Decimal)
    case accountLocked

    var errorDescription: String? {
        switch self {
        case .insufficientFunds(let shortfall):
            return "Insufficient funds: short by \(shortfall)."
        case .accountLocked:
            return "This account is locked."
        }
    }
}

// error.localizedDescription picks up errorDescription automatically.
```

## `do` / `try` / `catch` and multiple catch clauses

Match specific cases first; a catch-all with no pattern binds `error: any Error` and must come last.

```swift
do {
    try withdraw(500, from: account)
} catch AccountError.insufficientFunds(let shortfall) {
    print("need \(shortfall) more")
} catch AccountError.accountLocked {
    print("locked, contact support")
} catch {
    print("unexpected: \(error)")   // catch-all, only if the function is untyped-throws
}
```

With typed throws, the compiler enforces exhaustiveness on the specific enum; you can omit the untyped catch-all entirely.

## Error propagation across a call chain

Mark every intermediate function `throws` (or `throws(SameErrorType)`) and use `try` at each call site; do not catch-and-rethrow unless you're translating the error type.

```swift
func readConfig() throws(ConfigError) -> Config { /* ... */ }
func loadApp() throws(ConfigError) -> App {
    let config = try readConfig()   // propagates ConfigError automatically
    return App(config: config)
}
```

To translate one error domain into another as it propagates, catch and rethrow the mapped type explicitly — never swallow the original with an empty `catch {}`.

```swift
func loadAppOrFail() throws(AppError) -> App {
    do {
        return try loadApp()
    } catch {
        throw AppError.configurationFailed(underlying: error)
    }
}
```

## `rethrows`

A `rethrows` function only throws if the closure passed to it throws; it cannot throw independently. Use it for higher-order functions that forward a caller-supplied throwing closure.

```swift
func retryOnce<T>(_ body: () throws -> T) rethrows -> T {
    do {
        return try body()
    } catch {
        return try body()   // second attempt; still only rethrows body's error
    }
}
```

## `try?` and `try!`

`try?` converts a thrown error into `nil` (or `Result` in some contexts), discarding the error entirely — use only when the caller genuinely doesn't need the failure reason (e.g. "best-effort" lookups). `try!` crashes on any thrown error — use only when failure is a programmer invariant violation, never for input-dependent I/O or parsing.

```swift
let cached = try? loadFromCache(key)     // nil on failure, error details lost
let config = try! Config(bundledJSON)    // crashes if the bundled resource is malformed — acceptable only if that's impossible by construction
```

Avoid `try?` as a substitute for real error handling in application logic; it is a common source of silently-swallowed failures in agent-generated code.
