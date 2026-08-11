# Protocols and Generics

## Protocol basics

A protocol declares requirements (methods, properties, initializers) that a conforming type must satisfy; conformance is declared with `:` and can be added retroactively in an extension.

```swift
protocol Identifiable2 {
    associatedtype ID: Hashable
    var id: ID { get }
}

struct User: Identifiable2 {
    let id: Int
    let name: String
}
```

## Protocol extensions with default implementations

A protocol extension supplies a default implementation that conforming types inherit for free and can override by providing their own.

```swift
protocol Greetable {
    var name: String { get }
    func greet() -> String
}

extension Greetable {
    func greet() -> String { "Hello, \(name)!" }   // default implementation
}

struct Guest: Greetable { let name: String }
Guest(name: "Ada").greet()   // "Hello, Ada!" — uses the default
```

Only requirements listed in the protocol are dynamically dispatched through an existential (`any Greetable`); extension-only methods not in the protocol are statically dispatched.

## Self requirements

A protocol can require a method to return `Self`, meaning "the concrete conforming type," which is useful for fluent/builder APIs and is enforced at compile time for non-final classes.

```swift
protocol Copyable2 {
    func copy() -> Self
}

struct Config: Copyable2 {
    var value: Int
    func copy() -> Self { Config(value: value) }
}
```

`Self` requirements make a protocol usable only as a generic constraint (`some Copyable2` / `<T: Copyable2>`), not as `any Copyable2`, because the concrete return type must be knowable.

## Protocol composition (&)

Combine multiple protocol requirements into one type constraint with `&`, without declaring a new named protocol.

```swift
protocol Named { var name: String { get } }
protocol Aged { var age: Int { get } }

func describe(_ person: some Named & Aged) -> String {
    "\(person.name) is \(person.age)"
}
```

## Protocol-oriented programming pattern

Prefer composing small protocols with default behavior over deep class hierarchies; types opt into behavior by conforming rather than inheriting.

```swift
protocol Loggable {
    func log(_ message: String)
}
extension Loggable {
    func log(_ message: String) { print("[LOG] \(message)") }
}

protocol Persistable: Loggable {
    func save()
}
extension Persistable {
    func save() { log("saving…") }
}

struct Document: Persistable {}
Document().save()   // "[LOG] saving…"
```

## Generic functions

A generic function operates on any type satisfying its parameter's constraints, determined once per call site at compile time (specialization), not at runtime.

```swift
func firstMatch<T: Equatable>(_ items: [T], equalTo target: T) -> T? {
    items.first { $0 == target }
}
```

## Generic types

Generic types parameterize over one or more placeholder types, reused across any concrete type satisfying the constraints.

```swift
struct Stack<Element> {
    private var items: [Element] = []
    mutating func push(_ item: Element) { items.append(item) }
    mutating func pop() -> Element? { items.popLast() }
}

var stack = Stack<Int>()
stack.push(1)
```

## Generic constraints and where clauses

Constrain a generic parameter with `:` for protocol/class conformance, and add extra requirements with a `where` clause on the declaration or an extension.

```swift
func allEqual<T: Sequence>(_ sequence: T) -> Bool where T.Element: Equatable {
    let elements = Array(sequence)
    guard let first = elements.first else { return true }
    return elements.allSatisfy { $0 == first }
}

extension Array where Element: Numeric {
    func sum() -> Element { reduce(0, +) }
}
```

## Associated types in protocols

`associatedtype` declares a placeholder type resolved by each conforming type; use a `where` clause to constrain the associated type of a generic parameter.

```swift
protocol Container {
    associatedtype Item
    var count: Int { get }
    subscript(index: Int) -> Item { get }
}

func printAll<C: Container>(_ container: C) where C.Item: CustomStringConvertible {
    for i in 0..<container.count { print(container[i].description) }
}
```

## some vs any

`some Protocol` (an opaque type) fixes one concrete, compile-time-known type per call site with full static dispatch and no boxing overhead; `any Protocol` (an existential) can hold any conforming type at runtime, boxed, with dynamic dispatch and a small performance cost.

```swift
func makeShape() -> some Shape { Circle(radius: 1) }   // same concrete type every call

var shapes: [any Shape] = [Circle(radius: 1), Square(side: 2)]   // heterogeneous
```

Prefer `some` for return types and parameters when a single concrete type suffices; reach for `any` only when you need a mixed collection or to erase the type across an API boundary. Since Swift 5.7, `any` must be written explicitly for existential protocol types.
