# Ownership Modifiers and Noncopyable Types

## Default parameter ownership: implicit borrowing

Every Swift function parameter is implicitly `borrowing` unless marked otherwise: the callee gets read-only, non-owning access for the duration of the call, and the caller retains ownership. You never need to write `borrowing` for ordinary read-only use — it's the default.

```swift
func area(of rect: Rectangle) -> Double {   // rect is implicitly borrowing
    rect.width * rect.height
}
```

Write `borrowing` explicitly only when you need it on a type that would otherwise default to `consuming` semantics in generic/noncopyable contexts, or for documentation clarity in performance-sensitive code.

```swift
func describe(_ handle: borrowing FileHandle) {
    print(handle.path)                       // read-only access, no ownership transfer
}
```

## `consuming` parameters

`consuming` transfers ownership of the argument into the function; the caller can no longer use the value afterward (for a noncopyable type) or, for a copyable type, the compiler may skip a retain/copy since the callee now owns it.

```swift
struct ConnectionToken: ~Copyable {
    let raw: Int32
    deinit { closeConnection(raw) }
}

func store(_ token: consuming ConnectionToken) {
    activeTokens.append(token)               // token's lifetime now belongs here
}

let token = ConnectionToken(raw: 42)
store(token)
// using `token` again here is a compile error: it was consumed
```

## `inout` parameters and exclusivity

`inout` gives the callee temporary, exclusive read-write access to the caller's storage; Swift enforces exclusivity so no other access to that same storage can overlap for the duration of the call, catching data races and aliasing bugs at compile time or via runtime traps.

```swift
func increment(_ value: inout Int) {
    value += 1
}
var counter = 0
increment(&counter)
```

```swift
// Exclusivity violation: passing the same inout storage into two overlapping
// accesses. This is a compile-time error ("overlapping accesses").
func swapBoth(_ a: inout Int, _ b: inout Int) { (a, b) = (b, a) }
var x = 1
swapBoth(&x, &x)   // error: conflicting accesses to x
```

Fix exclusivity errors by restructuring so accesses don't overlap — read into a local first, or split the call — rather than suppressing the diagnostic.

```swift
var total = 0
func addAndLog(_ n: inout Int) {
    let snapshot = n            // read completes before mutation starts
    n += 1
    print("was \(snapshot), now \(n)")
}
```

## `borrowing`/`consuming` on methods (`self` ownership)

Methods can mark how they take `self`: `mutating` for in-place struct mutation (implicit `inout self`), `consuming` when the method ends the value's lifetime (e.g. transforming it into something else), and a plain (non-mutating) method borrows `self`.

```swift
struct Ticket: ~Copyable {
    let seat: String
    consuming func redeem() -> String {
        defer { discard self }   // skip deinit: value has been fully consumed here
        return seat
    }
    deinit { print("Ticket for \(seat) destroyed unused") }
}
```

`discard self` is only legal inside a `consuming` method of a `~Copyable` type and tells the compiler this particular consumption already handled cleanup, so the (possibly side-effect-having) `deinit` should not also run.

## Noncopyable types: `~Copyable`

Suppressing the implicit `Copyable` conformance with `~Copyable` makes a struct/enum a move-only type: it can be passed around and have ownership transferred, but never implicitly duplicated — the compiler enforces single ownership at each point in the program.

```swift
struct FileDescriptor: ~Copyable {
    private let fd: Int32
    init(fd: Int32) { self.fd = fd }
    deinit {
        if fd >= 0 { close(fd) }        // guaranteed single close, no double-close risk
    }
}

func take(_ f: consuming FileDescriptor) { /* now owns f */ }
let f = FileDescriptor(fd: 3)
take(f)
// take(f) again here: compile error, f was already consumed
```

Reach for `~Copyable` when there is a real uniqueness invariant to enforce — a resource handle, a lock guard, a token that must be redeemed exactly once — not for ordinary data models; an accidental extra copy of ordinary data is harmless, but an accidental extra copy of a lock or file handle is a correctness bug, which is exactly what `~Copyable` prevents at compile time.

## `deinit` on noncopyable types

Noncopyable structs/enums can declare `deinit`, just like classes, which runs exactly once when the value's owner lets it go out of scope (end of scope, explicit `consuming` use, or reassignment) — this is what makes them useful as compile-time-checked RAII guards without heap allocation or ARC overhead.

```swift
struct Lock: ~Copyable {
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>
    init(_ mutex: UnsafeMutablePointer<pthread_mutex_t>) {
        self.mutex = mutex
        pthread_mutex_lock(mutex)
    }
    deinit { pthread_mutex_unlock(mutex) }   // unlocked exactly once, deterministically
}
```

## `~Escapable`

`~Escapable` (paired with the `Escapable` marker protocol) marks a type whose values must not outlive a particular scope/lifetime — used for types like `Span`/`RawSpan` that wrap a borrowed buffer and must not be stored past the lifetime of what they point into. Treat it as an advanced tool for library authors modeling borrowed-buffer views; most application code never declares `~Escapable` types directly, it only consumes standard-library ones like `Span`.

```swift
struct BufferView: ~Escapable {
    let base: UnsafePointer<UInt8>
    let count: Int
    // a BufferView cannot be returned/stored beyond the lifetime it was derived from
}
```

## Unsafe pointers and `Unmanaged` — last resort for interop

`UnsafePointer<T>`/`UnsafeMutablePointer<T>` and `Unmanaged<T>` bypass Swift's memory safety and ARC guarantees entirely: use them ONLY when a C or Objective-C API literally requires a raw pointer or a manually-retained-count object, and prefer the safe alternative (`withUnsafeBufferPointer`, `withUnsafePointer(to:)`, plain class references) whenever it exists. Getting the retain/release or lifetime bookkeeping wrong here causes crashes or silent memory corruption that the compiler cannot catch.

```swift
// Safe, scoped access — no manual allocation/deallocation needed.
var value = 42
withUnsafePointer(to: &value) { ptr in
    callCFunction(ptr)
}

// Manual allocation: you own the balance of allocate/deallocate and initialize/deinitialize.
let buffer = UnsafeMutablePointer<Int>.allocate(capacity: 10)
buffer.initialize(repeating: 0, count: 10)
defer {
    buffer.deinitialize(count: 10)
    buffer.deallocate()
}

// Unmanaged: for CF/toll-free-bridged APIs that hand you an object without ARC tracking it.
let cfObj: CFString = "hello" as CFString
let raw = Unmanaged.passRetained(cfObj).toOpaque()   // +1 retain, you owe a release
let back = Unmanaged<CFString>.fromOpaque(raw).takeRetainedValue()  // consumes that +1
```

Guidance: if you find yourself reaching for `UnsafePointer`/`Unmanaged` outside a C-interop boundary, stop and use swift-interop's guidance instead — there is almost always a safe Swift idiom (value types, `consuming`/`borrowing`, `~Copyable` RAII wrappers) that solves the same problem without opting out of memory safety.
