# Actors, Sendable, and Strict Concurrency

## Actors isolate mutable state

An `actor` serializes access to its mutable state — only one task executes inside it at a time, eliminating data races without manual locks. Access from outside requires `await`, even for property reads.

```swift
actor Cache {
    private var storage: [String: Data] = [:]

    func set(_ data: Data, for key: String) {
        storage[key] = data
    }

    func get(_ key: String) -> Data? {
        storage[key]
    }
}

let cache = Cache()
await cache.set(data, for: "profile")
let value = await cache.get("profile")
```

`nonisolated` opts a member out of isolation for state that is inherently safe to read without synchronization (e.g., a `let` constant).

```swift
actor Session {
    nonisolated let id: UUID = UUID()
    private var lastSeen: Date = .now
}
```

## `@MainActor` for UI and shared singletons

`@MainActor` pins a type, method, or property to the main thread's serial executor. Apply it to whole types (view models, UI controllers) rather than sprinkling it on individual methods, so isolation is consistent.

```swift
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var name: String = ""

    func load() async {
        let user = try? await fetchUser(id: 1)
        name = user?.name ?? ""
    }
}
```

Calling a `@MainActor` method from a non-isolated `async` context requires `await`; calling into it from synchronous, non-isolated code requires wrapping in `Task { @MainActor in ... }` or marking the caller `@MainActor` too.

## `Sendable`: what crosses concurrency domains safely

A type is `Sendable` if it's safe to share across actor/task boundaries — either because it's immutable, a value type with `Sendable` members, or internally synchronized (like an `actor`). Swift 6 requires values crossing isolation boundaries to be `Sendable`.

```swift
struct UserSnapshot: Sendable {
    let id: Int
    let name: String
}

final class Counter: Sendable {
    // Not actually thread-safe — do NOT do this to silence the compiler:
    // final class Counter: @unchecked Sendable { var count = 0 }
}
```

Prefer these structural fixes, in order, before ever reaching for `@unchecked Sendable`:
1. Make the type a `struct`/`enum` with only `Sendable` stored properties (value types are `Sendable` for free when their members are).
2. If it must be a reference type with mutable state, make it an `actor` instead of a `class`.
3. If it must stay a `class`, make all stored properties `let` and their types `Sendable` (an immutable class is safely `Sendable`).
4. Only if none of the above apply — e.g. wrapping a genuinely externally-synchronized C/Objective-C type — use `@unchecked Sendable`, and add a comment stating exactly why it's safe.

## `sending` parameters and results

`sending` marks a parameter or return value whose ownership transfers across an isolation boundary, letting a non-`Sendable` value move safely as long as the caller doesn't keep using it afterward. Use it instead of forcing a type to be `Sendable` when the value is only ever used by one owner at a time.

```swift
func process(_ buffer: sending Buffer) async {
    // buffer is safe to hop actors with, because the caller
    // gives up its reference to it here.
    await store(buffer)
}
```

## Common Swift 6 strict concurrency errors and fixes

**"Non-sendable type 'X' passed across actor boundary"** — the argument type isn't `Sendable`. Fix by applying the `Sendable` decision tree above, not by adding `@preconcurrency import`.

```swift
// Error: passing a class instance into an actor method
actor Store { func save(_ model: Model) { } }   // Model must be Sendable

// Fix: make Model a Sendable struct
struct Model: Sendable { let id: Int; let payload: [UInt8] }
```

**"Call to main actor-isolated method in a synchronous nonisolated context"** — wrap the call site, don't remove `@MainActor`.

```swift
Task { @MainActor in
    viewModel.load()
}
```

**"Actor-isolated property 'x' can not be referenced from a non-isolated context"** — read the property with `await` from outside the actor, or make it `nonisolated` only if it's genuinely immutable/constant.

**Suppressing errors with `@preconcurrency import`** — only appropriate for adopting a not-yet-updated third-party module boundary; it hides real races in your own code and should never be applied to your own types.

## Global actors beyond `@MainActor`

Define a custom global actor when several unrelated types must share one serialization domain other than the main thread.

```swift
@globalActor
actor DatabaseActor {
    static let shared = DatabaseActor()
}

@DatabaseActor
final class Repository {
    func save(_ record: Record) { /* isolated to DatabaseActor */ }
}
```

## Stop conditions for this file

- Shared mutable state lives in an `actor`, not behind manual locking or `@unchecked Sendable`.
- All values crossing actor/task boundaries are `Sendable` or explicitly `sending`.
- The code compiles under Swift 6 language mode with zero added suppressions (`@unchecked Sendable`, `@preconcurrency`) beyond pre-existing, justified ones.
