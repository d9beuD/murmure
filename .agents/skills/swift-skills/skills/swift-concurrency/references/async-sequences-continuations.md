# AsyncSequence, AsyncStream, and Continuations

## Consuming an `AsyncSequence`

Iterate any `AsyncSequence` with `for await`; use `try await` if the sequence's `Failure` type can throw. This works the same whether the sequence is a built-in `AsyncStream` or a custom conformance.

```swift
func consume(_ lines: some AsyncSequence<String, Never>) async {
    for await line in lines {
        print(line)
    }
}
```

## `AsyncStream` for non-throwing event bridging

`AsyncStream` wraps a push-based producer (delegate callback, notification, timer) as a pull-based async sequence. The `onTermination` handler fires when the consumer stops iterating or cancels, so cleanup belongs there, not after the loop.

```swift
func heartbeat(interval: Duration) -> AsyncStream<Date> {
    AsyncStream { continuation in
        let task = Task {
            while !Task.isCancelled {
                continuation.yield(.now)
                try? await Task.sleep(for: interval)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}
```

Call `continuation.finish()` exactly once to end the stream; calls to `yield` after `finish()` are silently dropped.

## `AsyncThrowingStream` for producers that can fail

Identical shape to `AsyncStream`, but `finish(throwing:)` lets the producer terminate the sequence with an error that consumers receive via `try await`.

```swift
func watchFile(_ url: URL) -> AsyncThrowingStream<Data, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                for try await chunk in FileWatcher(url) {
                    continuation.yield(chunk)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
```

## Backpressure with `AsyncStream.Continuation.BufferingPolicy`

Bound unbounded producers with a buffering policy so a fast producer can't grow memory unboundedly while the consumer is slow.

```swift
let stream = AsyncStream<Int>(bufferingPolicy: .bufferingNewest(10)) { continuation in
    for i in 0..<1_000_000 {
        continuation.yield(i)
    }
    continuation.finish()
}
```

## Custom `AsyncSequence` conformance

Implement `AsyncSequence` and `AsyncIteratorProtocol` directly when you need custom iteration state rather than a simple push bridge; this is the lower-level tool `AsyncStream` is built on.

```swift
struct Countdown: AsyncSequence {
    typealias Element = Int
    let start: Int

    struct AsyncIterator: AsyncIteratorProtocol {
        var current: Int
        mutating func next() async -> Int? {
            guard current > 0 else { return nil }
            defer { current -= 1 }
            try? await Task.sleep(for: .milliseconds(200))
            return current
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(current: start)
    }
}
```

## Bridging callback APIs with checked continuations

Use `withCheckedContinuation` (non-throwing) or `withCheckedThrowingContinuation` (throwing) to wrap exactly one completion-handler call as a single `await`. The runtime traps in debug builds if the continuation resumes zero or more than once, which is the main bug class to guard against.

```swift
func requestLocation() async throws -> CLLocation {
    try await withCheckedThrowingContinuation { continuation in
        legacyLocationManager.requestLocation { location, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let location {
                continuation.resume(returning: location)
            } else {
                continuation.resume(throwing: LocationError.unknown)
            }
        }
    }
}
```

Every exit path of the callback (success, failure, and any "cancelled"/"timed out" branch) must call `resume` exactly once — an early `return` before the callback fires, or a callback invoked twice by the underlying API, are the two most common ways this breaks.

## Continuation + cancellation

Checked continuations do not automatically observe task cancellation. Register a cancellation handler explicitly with `withTaskCancellationHandler` when the underlying operation is cancellable, and still resume the continuation from the cancellation path.

```swift
func fetchWithCancellation() async throws -> Data {
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let handle = legacyClient.start { result in
                continuation.resume(with: result)
            }
            activeHandle = handle
        }
    } onCancel: {
        activeHandle?.cancel()
    }
}
```

## Stop conditions for this file

- The custom sequence or bridged stream compiles and delivers values via `for await`/`try await`.
- Every continuation resumes exactly once on every code path, including error and early-return paths.
- Producer cleanup happens in `onTermination` (streams) or the cancellation handler (continuations), not after the consuming loop.
