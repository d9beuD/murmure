# Result, Defer, and Retry Patterns

## `Result<Success, Failure>` basics

`Result` holds either a `.success(Success)` or `.failure(Failure)` value, letting a failure be stored, passed around, or returned from a non-throwing context (Failure must conform to `Error`).

```swift
enum FetchError: Error { case notFound, timedOut }

func fetchCached(id: String) -> Result<Data, FetchError> {
    guard let data = cache[id] else { return .failure(.notFound) }
    return .success(data)
}

switch fetchCached(id: "42") {
case .success(let data): process(data)
case .failure(.notFound): print("no cached entry")
case .failure(.timedOut): print("timed out")
}
```

## `map`, `flatMap`, `mapError`

`map` transforms the success value; `flatMap` chains another `Result`-producing step without nesting; `mapError` transforms the failure value. All leave the other case untouched.

```swift
let sized: Result<Int, FetchError> = fetchCached(id: "42").map { $0.count }

let decoded: Result<Model, FetchError> = fetchCached(id: "42")
    .flatMap { data in
        (try? JSONDecoder().decode(Model.self, from: data)).map(Result.success)
            ?? .failure(.notFound)
    }

let publicFacing: Result<Data, PublicError> = fetchCached(id: "42")
    .mapError { PublicError.wrapping($0) }
```

## Converting `Result` to/from throwing code

`.get()` unwraps a `Result`, throwing the failure if present — the bridge from `Result` back into `try`-based code. `Result(catching:)` builds a `Result` from a throwing closure — the bridge the other way.

```swift
func value() throws -> Data {
    try fetchCached(id: "42").get()      // throws FetchError.notFound, etc.
}

let result = Result { try JSONDecoder().decode(Model.self, from: data) }
// result: Result<Model, any Error>
```

Prefer plain `throws` for most application code; reach for `Result` specifically when a value must cross a boundary that can't `throw` — stored properties, completion-handler callbacks, or collections of outcomes.

```swift
func loadAll(ids: [String]) -> [Result<Data, FetchError>] {
    ids.map { fetchCached(id: $0) }      // heterogeneous outcomes, no throw here
}
```

## `defer` for guaranteed cleanup

A `defer` block runs when the enclosing scope exits — normally, via `return`, or via a thrown error — in reverse order of declaration. Place it immediately after acquiring the resource it releases.

```swift
func processFile(at path: String) throws {
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { handle.closeFile() }         // runs on every exit path

    let data = handle.readDataToEndOfFile()
    guard !data.isEmpty else { throw ParseError.emptyInput }
    try process(data)
}
```

Multiple `defer` statements in one scope run last-declared-first, mirroring stack unwind order — useful when releases have an ordering dependency (e.g. unlock after closing).

```swift
func withLockedFile() throws {
    lock.acquire()
    defer { lock.release() }             // runs second

    let handle = try open()
    defer { handle.close() }             // runs first
    try use(handle)
}
```

## Retry pattern around a throwing operation

Bound every retry loop with a max-attempt count and a specific set of retryable errors; never retry unconditionally or without a limit, and re-throw the last error once attempts are exhausted.

```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    operation: () throws(FetchError) -> T
) throws(FetchError) -> T {
    var lastError: FetchError!
    for attempt in 1...maxAttempts {
        do {
            return try operation()
        } catch {
            lastError = error
            guard error == .timedOut else { throw error }   // only retry timeouts
            if attempt < maxAttempts {
                Thread.sleep(forTimeInterval: 0.2 * Double(attempt))  // simple backoff
            }
        }
    }
    throw lastError
}
```

For async retry loops with `Task.sleep` and cancellation checks, see swift-concurrency; this pattern covers the synchronous throw/catch mechanics only.

## Choosing `Result` vs `throws` at a boundary

Use this quick rule: if the caller can act immediately with `try`/`do`/`catch`, use `throws`. If the outcome must be stored, queued, returned from a `@Sendable` closure, or compared/pattern-matched later, use `Result`.

```swift
struct FetchOutcome {
    let id: String
    let result: Result<Data, FetchError>   // stored for later inspection
}
```
