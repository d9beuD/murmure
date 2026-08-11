# Structs, Classes, and Enums

## Struct vs class: value vs reference semantics

Structs copy on assignment/pass (value semantics); classes share a single instance via references (reference semantics). Default to `struct` unless you need identity, inheritance, or mutable shared state.

```swift
struct Point { var x: Double; var y: Double }   // copied on assignment
var a = Point(x: 0, y: 0)
var b = a          // b is an independent copy
b.x = 5            // a.x is still 0

final class Counter { var value = 0 }           // shared reference
let c1 = Counter()
let c2 = c1        // c2 points to the same instance
c2.value = 5       // c1.value is also 5
```

Use `class` when you need `deinit`, subclassing, Objective-C interop, or `===` identity comparison. Mark classes `final` unless subclassing is intended — this improves performance and clarifies intent.

## Mutating methods on structs

Struct methods that modify `self` must be marked `mutating`; this is not needed for classes since their methods can always mutate stored `var` properties.

```swift
struct Account {
    var balance: Decimal
    mutating func deposit(_ amount: Decimal) {
        balance += amount
    }
}
```

## Enums with associated values

Associated values let each case carry different payload types, making illegal states unrepresentable.

```swift
enum NetworkResult {
    case success(data: Data, statusCode: Int)
    case failure(Error)
    case loading
}

func handle(_ result: NetworkResult) {
    switch result {
    case .success(let data, let statusCode):
        print("\(statusCode): \(data.count) bytes")
    case .failure(let error):
        print("error: \(error)")
    case .loading:
        print("loading…")
    }
}
```

## Enums with raw values and CaseIterable

Raw values give each case a fixed literal representation (`String`, `Int`, etc.) via `RawRepresentable`; `CaseIterable` generates an `allCases` collection.

```swift
enum HTTPMethod: String, CaseIterable {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

HTTPMethod(rawValue: "POST")   // Optional(HTTPMethod.post)
HTTPMethod.allCases            // [.get, .post, .delete]
HTTPMethod.get.rawValue         // "GET"
```

A case cannot have both a raw value and an associated value; choose one per enum.

## Indirect enums (recursive)

`indirect` boxes a case (or the whole enum) on the heap so it can reference itself, which is required for recursive data structures like trees or expressions.

```swift
indirect enum Expr {
    case literal(Int)
    case add(Expr, Expr)
    case multiply(Expr, Expr)
}

func evaluate(_ expr: Expr) -> Int {
    switch expr {
    case .literal(let value): return value
    case .add(let lhs, let rhs): return evaluate(lhs) + evaluate(rhs)
    case .multiply(let lhs, let rhs): return evaluate(lhs) * evaluate(rhs)
    }
}
```

Mark only the recursive case as `indirect case add(Expr, Expr)` if most cases are not recursive, to avoid unnecessary boxing.

## Computed properties

A computed property has no storage; it recomputes its value from a getter (and optional setter) every access.

```swift
struct Rectangle {
    var width: Double
    var height: Double
    var area: Double { width * height }              // read-only
    var perimeter: Double {
        get { 2 * (width + height) }
        set { width = newValue / 4; height = newValue / 4 }
    }
}
```

## Property observers: willSet / didSet

`willSet` runs just before a stored property changes, `didSet` just after; both are unavailable on computed properties and on properties declared inside their own initializer assignment.

```swift
struct Thermostat {
    var targetTemperature: Double = 20 {
        willSet { print("changing from \(targetTemperature) to \(newValue)") }
        didSet { if targetTemperature > 30 { targetTemperature = 30 } }
    }
}
```

`didSet` can reference `oldValue`; reassigning the property inside `didSet` does not re-trigger the observer.

## Enum methods and computed properties

Enums can define methods and computed properties, including ones that switch over `self`, which keeps behavior colocated with the case data.

```swift
enum Direction: CaseIterable {
    case north, south, east, west

    var opposite: Direction {
        switch self {
        case .north: return .south
        case .south: return .north
        case .east: return .west
        case .west: return .east
        }
    }
}
```

## Classes: inheritance and deinit

Only classes support inheritance and deinitializers; override members with `override`, and call `super` explicitly when needed.

```swift
class Vehicle {
    var speed = 0.0
    func describe() -> String { "moving at \(speed)" }
}

final class Car: Vehicle {
    var brand: String
    init(brand: String) { self.brand = brand; super.init() }
    override func describe() -> String { "\(brand) " + super.describe() }
    deinit { print("\(brand) deallocated") }
}
```
