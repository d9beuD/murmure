# Extensions and Property Wrappers

## Extending existing types

`extension` adds methods, computed properties, initializers, or protocol conformances to a type you did not define, including standard-library and third-party types.

```swift
extension Int {
    var isEven: Bool { self % 2 == 0 }
    func repeated(_ body: () -> Void) {
        for _ in 0..<self { body() }
    }
}

3.repeated { print("hi") }   // prints "hi" 3 times
```

Extensions cannot add stored properties or override existing members; they can only add new computed properties and new functionality.

## Adding protocol conformance via extension

Conform an existing type to a protocol in a separate extension to keep the primary declaration focused, or to retroactively conform a type you don't own.

```swift
protocol Summable { static func + (lhs: Self, rhs: Self) -> Self }

struct Money { var cents: Int }
extension Money: Summable {
    static func + (lhs: Money, rhs: Money) -> Money { Money(cents: lhs.cents + rhs.cents) }
}
```

## Conditional conformance

An extension can make a generic type conform to a protocol only when its generic parameter also satisfies a constraint, via a `where` clause.

```swift
struct Box<Wrapped> { let value: Wrapped }

extension Box: Equatable where Wrapped: Equatable {
    static func == (lhs: Box, rhs: Box) -> Bool { lhs.value == rhs.value }
}

Box(value: 1) == Box(value: 1)        // OK, Int is Equatable
// Box(value: URL) == Box(value: URL) // error if URL isn't Equatable
```

The standard library uses this pattern extensively — e.g. `Array: Equatable` only when `Element: Equatable`.

## Extending protocols with constrained defaults

A protocol extension's default implementation can itself be scoped with `where`, so it only applies to conforming types meeting extra requirements.

```swift
protocol Describable { var items: [String] { get } }

extension Describable where Self: CustomStringConvertible {
    var description: String { items.joined(separator: ", ") }
}
```

## Custom property wrappers: basics

`@propertyWrapper` types encapsulate storage/logic behind a `wrappedValue`; applying `@WrapperName` to a property routes reads/writes through the wrapper.

```swift
@propertyWrapper
struct Clamped<Value: Comparable> {
    private var value: Value
    private let range: ClosedRange<Value>

    init(wrappedValue: Value, _ range: ClosedRange<Value>) {
        self.range = range
        self.value = min(max(wrappedValue, range.lowerBound), range.upperBound)
    }

    var wrappedValue: Value {
        get { value }
        set { value = min(max(newValue, range.lowerBound), range.upperBound) }
    }
}

struct Volume {
    @Clamped(0...100) var level: Int = 50
}

var v = Volume()
v.level = 200   // clamped to 100
```

## Property wrappers with projectedValue

A `projectedValue` property exposes a secondary view of the wrapper accessible via `$propertyName`, commonly used for bindings or status flags.

```swift
@propertyWrapper
struct Traced<Value> {
    private var value: Value
    private(set) var changeCount = 0

    init(wrappedValue: Value) { self.value = wrappedValue }

    var wrappedValue: Value {
        get { value }
        set { value = newValue; changeCount += 1 }
    }

    var projectedValue: Int { changeCount }
}

struct Session {
    @Traced var attempts: Int = 0
}

var s = Session()
s.attempts = 1
s.attempts = 2
s.$attempts   // 2 — number of writes so far
```

## Property wrappers with additional init arguments

A wrapper's `init(wrappedValue:)` can take extra parameters supplied in the attribute itself, letting each usage site configure the wrapper's behavior.

```swift
@propertyWrapper
struct Capitalized {
    private var value: String
    var wrappedValue: String {
        get { value }
        set { value = newValue.capitalized }
    }
    init(wrappedValue: String) { self.value = wrappedValue.capitalized }
}

struct Person {
    @Capitalized var name: String
}

var p = Person(name: "ada lovelace")
p.name   // "Ada Lovelace"
```
