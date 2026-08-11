# Control Flow and Pattern Matching

## if / else

Conditions must be `Bool`; there is no truthy/falsy coercion of other types.

```swift
let temperature = 18

if temperature > 25 {
    print("Hot")
} else if temperature > 15 {
    print("Mild")
} else {
    print("Cold")
}
```

## switch

`switch` in Swift must be exhaustive over the matched type; cases do not fall through by default, and `default` covers any remaining cases.

```swift
let statusCode = 404

switch statusCode {
case 200:
    print("OK")
case 400, 401, 403:
    print("Client error")
case 500...599:
    print("Server error")
default:
    print("Other: \(statusCode)")
}
```

## Range and Tuple Patterns

Ranges (`...`, `..<`) match against a value inside `switch`, and tuple patterns can match multiple values positionally, including partial wildcards (`_`).

```swift
let point = (2, 0)

switch point {
case (0, 0):
    print("Origin")
case (_, 0):
    print("On x-axis")
case (0, _):
    print("On y-axis")
case (-2...2, -2...2):
    print("Near origin")
default:
    print("Elsewhere")
}
```

## Value Binding and `where`

`switch` cases can bind matched components to names and add a `where` clause for extra conditions.

```swift
let coordinate = (12, -4)

switch coordinate {
case (let x, let y) where x == y:
    print("On the diagonal")
case (let x, 0):
    print("On x-axis at \(x)")
case let (x, y) where x > 0 && y > 0:
    print("First quadrant: \(x), \(y)")
default:
    print("Somewhere else")
}
```

## Pattern Matching with Enums and Optionals

`switch` destructures enum associated values directly, and `case let x?` matches a non-nil optional while binding its wrapped value.

```swift
enum NetworkResult {
    case success(code: Int)
    case failure(message: String)
}

let result = NetworkResult.success(code: 200)

switch result {
case .success(let code) where code < 300:
    print("Success: \(code)")
case .success(let code):
    print("Unexpected success code: \(code)")
case .failure(let message):
    print("Failed: \(message)")
}

let maybeInt: Int? = 5
switch maybeInt {
case .some(let value):
    print("Value: \(value)")
case .none:
    print("Nothing")
}
```

## for-in

`for-in` iterates over any `Sequence`; use `where` to filter inline and `_` to ignore the element.

```swift
for number in 1...5 {
    print(number)
}

for number in 1...10 where number % 2 == 0 {
    print("Even: \(number)")
}

for _ in 0..<3 {
    print("tick")
}

let scores = ["Ada": 98, "Grace": 95]
for (name, score) in scores {
    print("\(name): \(score)")
}
```

`stride(from:to:by:)` and `stride(from:through:by:)` give non-1 step iteration.

```swift
for value in stride(from: 0, to: 10, by: 2) {
    print(value)          // 0, 2, 4, 6, 8
}
```

## while / repeat-while

`while` checks the condition before each iteration; `repeat-while` (Swift's do-while) checks after, guaranteeing at least one pass.

```swift
var attempts = 0
while attempts < 3 {
    attempts += 1
}

var input = ""
repeat {
    input = "retry"
} while input.isEmpty
```

## Control Transfer and Labeled Statements

`break`, `continue`, and labeled loops control nested iteration precisely; `fallthrough` opts into C-style fallthrough inside a `switch` case.

```swift
outer: for i in 1...3 {
    for j in 1...3 {
        if j == 2 { continue outer }
        if i == 3 { break outer }
        print(i, j)
    }
}

let letterGrade = "B"
switch letterGrade {
case "A":
    print("Excellent")
    fallthrough
case "B":
    print("Good or better")
default:
    print("Other")
}
```
