# Basic Types and Optionals

## Constants, Variables, and Type Inference

Use `let` for values that never change and `var` only when mutation is required; Swift infers the type from the initializer.

```swift
let maxRetries = 3            // Int, inferred
var userName = "ada"          // String, inferred
let ratio: Double = 1         // explicit type overrides Int-literal inference
```

Multiple bindings can be declared on one line, and type annotations are required only when there is no initializer or when the inferred type would be wrong.

```swift
var x = 0.0, y = 0.0, z = 0.0
var pending: [String]          // no initializer, needs annotation
```

## Primitive Types

`Int`, `Double`, `Bool`, and `String` are the everyday scalar types; `Int` is 64-bit on all modern platforms and `Double` is the default for floating-point literals.

```swift
let count: Int = 42
let price: Double = 19.99
let isReady: Bool = true
let label: String = "build"

let big = 1_000_000            // underscores allowed in numeric literals
let hex = 0x2A
let converted = Int("42") ?? 0 // failable String -> Int conversion
let asString = String(count)   // Int -> String
```

Numeric conversions between types are always explicit — there is no implicit widening.

```swift
let i = 7
let d = Double(i)              // explicit conversion required
let backToInt = Int(d.rounded())
```

## Optionals

`Optional<T>` (sugared as `T?`) represents a value that may be absent (`nil`). Force-unwrapping with `!` crashes at runtime if the value is `nil`, so prefer safe unwrapping.

```swift
var age: Int? = nil
age = 30

let name: String? = "Grace"
let forced = name!             // crashes if name is nil; avoid unless provably non-nil
```

`if let` binds the unwrapped value only inside the `if` branch; Swift 5.7+ (including 6.3) supports the shorthand `if let x` when the optional and binding share the same name.

```swift
var response: String? = "ok"

if let response {              // shorthand for `if let response = response`
    print("Got \(response)")
} else {
    print("No response")
}
```

`guard let` unwraps and exits early (`return`, `throw`, `break`, `continue`) when the value is `nil`, keeping the rest of the function unindented and working with the non-optional value afterward.

```swift
func process(_ input: String?) -> Int {
    guard let input, let value = Int(input) else {
        return 0
    }
    return value * 2
}
```

## Nil-Coalescing and Optional Chaining

`??` supplies a default when the left side is `nil`, short-circuiting so the right side is only evaluated if needed.

```swift
let stored: Int? = nil
let effective = stored ?? 10   // 10

func fallback() -> Int { 99 }
let lazy = stored ?? fallback() // fallback() only called because stored is nil
```

Optional chaining (`?.`, `?[]`) lets a call/property/subscript access on an optional propagate `nil` instead of crashing, and can be chained through multiple levels.

```swift
struct Address { var city: String? }
struct Person { var address: Address? }

let person: Person? = Person(address: Address(city: "Paris"))
let city = person?.address?.city ?? "Unknown"

let names: [String]? = ["Ada", "Grace"]
let firstUpper = names?.first?.uppercased()
```

## Multiple Optional Binding and `as?`

A single `if let`/`guard let` can unwrap several optionals at once, short-circuiting on the first `nil`; `as?` performs an optional downcast.

```swift
func combine(_ a: Int?, _ b: Int?) -> Int? {
    guard let a, let b else { return nil }
    return a + b
}

let anyValue: Any = 42
if let intValue = anyValue as? Int {
    print(intValue)
}
```

## Implicitly Unwrapped Optionals

`T!` auto-unwraps on use, useful for values set once after initialization but always accessed thereafter (rare in Swift 6 code; prefer regular optionals or non-optional properties when possible).

```swift
class ViewController {
    var titleLabel: String!    // assigned before first use, then treated as String
}
```
