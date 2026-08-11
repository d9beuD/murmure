# Async/Await and Structured Concurrency

## Basic async functions

An `async` function suspends instead of blocking; call it with `await` from another async context. Throwing and async compose independently — order is `async throws`.

```swift
func fetchUser(id: Int) async throws -> User {
    let (data, response) = try await URLSession.shared.data(from: userURL(id))
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw NetworkError.badStatus
    }
    return try JSONDecoder().decode(User.self, from: data)
}
```

## `async let` for a fixed number of children

`async let` starts a child task immediately; you must `await` every `async let` binding before it goes out of scope, or Swift inserts an implicit cancel-and-wait. Use it when you know the exact set of concurrent operations at compile time.

```swift
func loadDashboard() async throws -> Dashboard {
    async let profile = fetchProfile()
    async let feed = fetchFeed()
    async let notifications = fetchNotifications()
    return try await Dashboard(profile: profile, feed: feed, notifications: notifications)
}
```

If one `async let` throws, the others are automatically cancelled when awaited; Swift still requires every binding to be awaited on all paths.

## `TaskGroup` for a dynamic number of children

Use `withTaskGroup`/`withThrowingTaskGroup` when the number of child tasks is not known until runtime (e.g., one per element of a collection).

```swift
func downloadAll(urls: [URL]) async throws -> [Data] {
    try await withThrowingTaskGroup(of: (Int, Data).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let (data, _) = try await URLSession.shared.data(from: url)
                return (index, data)
            }
        }
        var results = [Data?](repeating: nil, count: urls.count)
        for try await (index, data) in group {
            results[index] = data
        }
        return results.map { $0! }
    }
}
```

`withThrowingTaskGroup` cancels all remaining children automatically when the body rethrows or when the group goes out of scope. Use `group.addTaskUnlessCancelled` to skip adding new work after cancellation, and `group.cancelAll()` to cancel early on a success condition (e.g., a race for the first result).

## Unstructured `Task { }` and priorities

`Task { }` starts work that outlives the current scope — the task is not a child of the calling task and is not automatically awaited or cancelled. Only reach for this when the structured forms above don't fit, e.g. firing work from a synchronous context or a UI action handler.

```swift
let handle: Task<Void, Never> = Task(priority: .userInitiated) {
    await refreshCache()
}
// Later, typically on view teardown:
handle.cancel()
```

`Task.detached { }` additionally does not inherit the parent's priority, task-local values, or actor context — prefer plain `Task { }` unless you specifically need isolation from the caller's context.

## Cancellation

Cancellation is cooperative: calling `.cancel()` sets a flag, it does not stop execution. Check `Task.isCancelled` or call `try Task.checkCancellation()` at loop iterations and before expensive work; `URLSession` and other Swift-aware APIs throw `CancellationError` automatically once cancelled.

```swift
func processAll(_ items: [Item]) async throws {
    for item in items {
        try Task.checkCancellation()
        try await process(item)
    }
}
```

## Priorities and inheritance

Task priority (`.high`, `.userInitiated`, `.medium`, `.low`, `.utility`, `.background`) informs the cooperative thread pool's scheduling and can be escalated automatically when a higher-priority task awaits a lower-priority one, but it never overrides `@MainActor` serialization.

## Task Stealers (Swift 6.3)

Swift 6.3 introduces Task Stealers, a scheduling primitive that lets idle threads in the cooperative thread pool pull queued work from other threads instead of leaving it pinned to the thread that enqueued it. This improves load balancing under bursty `TaskGroup`/unstructured-`Task` workloads without any source changes — there is no new API to write against; it only affects runtime scheduling behavior. Treat it as an under-the-hood scheduler change, not something to code around.

## Stop conditions for this file

- Structured concurrency (`async let`/`TaskGroup`) compiles and returns the expected values.
- Unstructured `Task { }` is only used where the work must outlive the caller, with cancellation handled explicitly.
- Cancellation checks exist at any loop or expensive step inside long-running tasks.
