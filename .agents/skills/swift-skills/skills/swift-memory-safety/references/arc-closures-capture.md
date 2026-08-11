# ARC, Closures, and Capture Lists

## How ARC works

Automatic Reference Counting increments a class instance's retain count on each strong reference and deallocates it (running `deinit`) when the count hits zero; structs/enums have no retain count because they are copied, not shared. Only `class` (and closures, which are reference types under the hood) participate in retain/release traffic.

```swift
final class Session {
    let id: UUID
    init(id: UUID) { self.id = id }
    deinit { print("Session \(id) deallocated") }
}

var a: Session? = Session(id: UUID())
var b = a          // strong ref, retain count 2
a = nil            // retain count 1, deinit NOT called yet
b = nil            // retain count 0, deinit called
```

## Strong, weak, and unowned references

`weak` references are optional, zero themselves out (become `nil`) when the referent is deallocated, and require the referenced type to be a class (or class-bound protocol); `unowned` references do not zero out and trap on access after deallocation, so use them only when the referenced object is guaranteed to outlive the reference.

```swift
final class Owner {
    var pet: Pet?
}
final class Pet {
    weak var owner: Owner?              // breaks the cycle: Owner -> Pet -> Owner
}

final class CreditCard {
    unowned let customer: Customer      // a card cannot outlive its customer
    init(customer: Customer) { self.customer = customer }
}
```

Use `unowned(unsafe)` only in hot paths that have already been profiled and where the lifetime invariant is airtight — it skips the runtime liveness check entirely and is memory-unsafe if violated.

## The classic retain cycle

Two class instances holding strong references to each other (directly, or through a closure property) never reach a retain count of zero, so neither `deinit` ever runs.

```swift
final class ViewModel {
    var onUpdate: (() -> Void)?         // closure property retained by self
}

final class ViewController {
    let viewModel = ViewModel()
    func bind() {
        viewModel.onUpdate = {
            self.render()                // closure captures self strongly -> cycle
        }
    }
}
```

`self` → `viewModel` → `onUpdate` closure → `self`: a cycle. Neither object's `deinit` runs even after the controller should be gone.

## Capture lists: `[weak self]` vs `[unowned self]` vs none

A capture list controls how a closure captures the variables it references; put it right after the opening `{` and before any parameters.

```swift
viewModel.onUpdate = { [weak self] in
    guard let self else { return }      // Swift 5.7+ shorthand optional unwrap
    self.render()
}

viewModel.onUpdate = { [unowned self] in
    self.render()                       // traps if self was already deallocated
}

// No capture list needed for a non-escaping closure (e.g. most higher-order
// functions) — it cannot outlive the current scope, so it cannot create a cycle.
[1, 2, 3].forEach { self.process($0) }
```

Decision guidance: use `[weak self]` whenever the closure is `@escaping` and stored somewhere that can outlive the call that created it (properties, completion handlers registered with a system API, `Timer`, `NotificationCenter` observers, Combine/AsyncSequence sinks). Use `[unowned self]` only when `self` structurally owns the only thing that can invoke the closure and cannot be deallocated while it's outstanding. Use no capture list for synchronous, non-escaping closures — there's no cycle risk.

## Capturing other values and mutable state

Capture lists can also capture arbitrary values by name, by renaming, or `weak`/`unowned` on any class-typed value, not just `self`; captured `let`/`var` values are captured by reference to the *variable* unless you capture-by-value explicitly.

```swift
var counter = 0
let increment = { [counter] in print(counter) }   // captures the value at closure creation

final class Downloader {
    func fetch(delegate: Delegate) {
        task.completion = { [weak delegate] data in
            delegate?.didFinish(data)
        }
    }
}
```

## Value semantics vs reference semantics

Structs and enums are value types: assignment and passing copy the value (Swift optimizes this with copy-on-write for types like `Array`/`Dictionary`/`String`, deferring the actual copy until a mutation would otherwise affect a shared buffer). Classes are reference types: assignment shares the same instance, so mutations are visible through every reference.

```swift
struct Point { var x, y: Double }
var p1 = Point(x: 0, y: 0)
var p2 = p1
p2.x = 5                 // p1.x is still 0 — independent copies

final class Counter { var value = 0 }
let c1 = Counter()
let c2 = c1
c2.value = 5              // c1.value is also 5 — shared instance
```

Copy-on-write means a large `Array`/`Dictionary` copy is O(1) until the first mutation on one of the copies, at which point that copy triggers an O(n) buffer copy; custom COW types implement this via `isKnownUniquelyReferenced` on an internal reference-typed storage class.

```swift
final class Storage { var items: [Int] = [] }
struct COWArray {
    private var storage = Storage()
    mutating func append(_ x: Int) {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage()  // clone to avoid mutating a shared buffer
        }
        storage.items.append(x)
    }
}
```

## Choosing struct/enum vs class for ARC reasons

Prefer value types by default: no retain/release traffic, no cycle risk, and thread-safe copies. Reach for `class` when identity matters (two variables should refer to the *same* underlying object), when mutation must be observable through every reference holder, or when interfacing with reference-semantic frameworks (UIKit/AppKit, Objective-C APIs). If you only need class for polymorphism/protocol dispatch, check swift-types-generics first — this file only covers the retention/lifetime consequences of that choice.
