# Collections and Strings

## Array

`Array<T>` is an ordered, random-access collection; literals infer element type, and mutation requires `var`.

```swift
var numbers = [1, 2, 3, 4, 5]
let empty: [String] = []
let repeated = Array(repeating: 0, count: 3)   // [0, 0, 0]

numbers.append(6)
numbers.insert(0, at: 0)
numbers.removeLast()
numbers.remove(at: 0)

let doubled = numbers.map { $0 * 2 }
let evens = numbers.filter { $0 % 2 == 0 }
let total = numbers.reduce(0, +)
let sorted = numbers.sorted(by: >)
let hasThree = numbers.contains(3)
let first = numbers.first { $0 > 2 }
```

Common queries and slicing operate without mutating the original array.

```swift
let names = ["Ada", "Grace", "Katherine"]
print(names.count)
print(names.isEmpty)
let slice = names[1...]        // ArraySlice<String>
let joined = names.joined(separator: ", ")
```

## Dictionary

`Dictionary<Key, Value>` stores unordered key-value pairs; subscript access returns an optional, and `updateValue` returns the previous value if any.

```swift
var scores: [String: Int] = ["Ada": 98, "Grace": 95]
scores["Katherine"] = 100
let previous = scores.updateValue(99, forKey: "Ada")   // 98

for (name, score) in scores {
    print("\(name): \(score)")
}

let names = Array(scores.keys)
let values = Array(scores.values)
let adaScore = scores["Ada", default: 0]
scores.removeValue(forKey: "Grace")
```

`mapValues`, `filter`, and merge combine or transform dictionaries functionally.

```swift
let bonused = scores.mapValues { $0 + 5 }
let passing = scores.filter { $0.value >= 95 }

var base = ["a": 1, "b": 2]
let extra = ["b": 20, "c": 3]
base.merge(extra) { current, _ in current }   // keeps existing value on conflict
```

## Set

`Set<T>` stores unique, unordered elements of a `Hashable` type and supports fast membership tests plus algebraic operations.

```swift
var primes: Set<Int> = [2, 3, 5, 7]
primes.insert(11)
primes.remove(2)

let a: Set = [1, 2, 3]
let b: Set = [2, 3, 4]

let union = a.union(b)              // [1, 2, 3, 4]
let intersect = a.intersection(b)   // [2, 3]
let subtracted = a.subtracting(b)   // [1]
let isSubset = a.isSubset(of: [1, 2, 3, 4])
```

## String Basics and Interpolation

`String` is a Unicode-correct value type; interpolation embeds any expression with `\(...)`.

```swift
let first = "Ada"
let last = "Lovelace"
let full = "\(first) \(last)"
let computed = "Sum: \(2 + 2)"

let concatenated = first + " " + last
var mutableGreeting = "Hello"
mutableGreeting += ", world!"
```

## Multiline Strings

Triple-quoted strings preserve line breaks; the closing `"""` sets the indentation baseline, and a trailing `\` suppresses a line break.

```swift
let poem = """
    Roses are red,
    Violets are blue.
    """

let noBreak = """
    First line \
    continues here.
    """
```

## Common String APIs

`count`, `isEmpty`, `contains`, `hasPrefix`/`hasSuffix`, case conversion, and splitting are the most-used operations; indices are `String.Index`, not `Int`.

```swift
let text = "Swift Programming"

print(text.count)                       // 18
print(text.isEmpty)                     // false
print(text.contains("Prog"))            // true
print(text.hasPrefix("Swift"))          // true
print(text.hasSuffix("ing"))            // true
print(text.uppercased())
print(text.lowercased())

let trimmed = "  padded  ".trimmingCharacters(in: .whitespaces)
let parts = text.split(separator: " ")  // ["Swift", "Programming"]
let replaced = text.replacingOccurrences(of: "Swift", with: "Modern")
```

Index-based access requires navigating via `String.Index` rather than integer subscripts because Swift strings are collections of `Character` grapheme clusters.

```swift
let word = "Hello"
let firstChar = word[word.startIndex]
let secondIndex = word.index(after: word.startIndex)
let prefix = word.prefix(3)             // "Hel"
let suffix = word.suffix(2)             // "lo"
```

## Tuples

Tuples group fixed-size heterogeneous values without declaring a named type; elements can be unlabeled (accessed by position) or labeled.

```swift
let httpError = (404, "Not Found")
print(httpError.0, httpError.1)

let point: (x: Int, y: Int) = (x: 3, y: 5)
print(point.x, point.y)

let (statusCode, message) = httpError   // destructuring
```

Functions commonly return tuples for multiple values, and `_` can ignore unwanted elements during destructuring.

```swift
func minMax(_ values: [Int]) -> (min: Int, max: Int)? {
    guard let first = values.first else { return nil }
    var low = first, high = first
    for value in values.dropFirst() {
        if value < low { low = value }
        if value > high { high = value }
    }
    return (low, high)
}

if let result = minMax([3, 1, 4, 1, 5]) {
    print("min: \(result.min), max: \(result.max)")
}

let (_, maxOnly) = (10, 20)
```
