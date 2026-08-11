# Result Builders and Reflection

Result builders transform a block of statement-like syntax into a composed value at compile time. Reflection inspects a value's structure at runtime. Both are Swift-level tools distinct from macros — no compiler plugin involved.

## Declaring a `@resultBuilder`

Mark a type `@resultBuilder` and give it a static `buildBlock(_:)` that combines the block's components into one value. Any function, closure, or initializer parameter typed as `@ClosureName () -> Content` can then be written with brace/statement syntax instead of explicit combinator calls.

```swift
@resultBuilder
struct HTMLBuilder {
    static func buildBlock(_ components: String...) -> String {
        components.joined()
    }
}

func html(@HTMLBuilder _ content: () -> String) -> String {
    content()
}

let page = html {
    "<h1>Title</h1>"
    "<p>Body</p>"
}
```

## Supporting `if`/`else` and loops

`if` without `else` needs `buildOptional(_:)`; `if`/`else` and `switch` need `buildEither(first:)`/`buildEither(second:)`; `for` loops need `buildArray(_:)`. Add only the ones the DSL's control flow actually uses — the compiler tells you exactly which is missing.

```swift
extension HTMLBuilder {
    static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }
    static func buildEither(first component: String) -> String { component }
    static func buildEither(second component: String) -> String { component }
    static func buildArray(_ components: [String]) -> String {
        components.joined()
    }
}

func row(showBadge: Bool) -> String {
    html {
        if showBadge {
            "<span>New</span>"
        } else {
            ""
        }
        for i in 1...3 {
            "<li>\(i)</li>"
        }
    }
}
```

An "ambiguous use of buildBlock" or "closure containing control flow statement cannot be used with function builder" error means a required `buildX` overload is missing for the control-flow construct present in the body.

## How `@ViewBuilder` fits the same model

SwiftUI's `@ViewBuilder` is an ordinary `@resultBuilder` type using the same `buildBlock`/`buildOptional`/`buildEither`/`buildArray` vocabulary, specialized to combine `some View` values instead of strings. Understanding the general mechanism above is enough to read or reason about SwiftUI body code without needing SwiftUI-specific APIs — actually building SwiftUI screens belongs to the SwiftUI/macOS skill, not this one.

```swift
// Same shape as HTMLBuilder, just producing View instead of String —
// shown for pattern-recognition only, not for writing SwiftUI UI here.
@resultBuilder
struct MinimalViewBuilder {
    static func buildBlock<V>(_ view: V) -> V { view }
}
```

## Buildable-value protocol for a custom DSL

A result builder is usually paired with a lightweight protocol/type so the DSL's leaf values compose into a real domain object rather than plain strings — this is the pattern behind SwiftUI's `View` and Swift's `RegexComponent`.

```swift
protocol Route { var path: String { get } }
struct Get: Route { let path: String }

@resultBuilder
struct RouteBuilder {
    static func buildBlock(_ routes: Route...) -> [Route] { routes }
}

func router(@RouteBuilder _ routes: () -> [Route]) -> [Route] { routes() }

let routes = router {
    Get(path: "/users")
    Get(path: "/posts")
}
```

## Runtime inspection with `Mirror`

`Mirror` reflects a value's stored properties without needing `Codable` or manual key lists — useful for logging, diffing, or generic debugging utilities. It works on any type but only sees stored properties, not computed ones or private implementation details beyond what the runtime exposes.

```swift
struct Point { var x: Double; var y: Double }

let mirror = Mirror(reflecting: Point(x: 1, y: 2))
for child in mirror.children {
    print(child.label ?? "?", "=", child.value)
}
// x = 1.0
// y = 2.0
```

## Swift 6.2+ `Reflection` module

Swift 6.2 introduced an early `Reflection` module (import `Reflection`) offering more structured, type-safe introspection than `Mirror`, including enumerating a type's fields with their names and types ahead of instantiation. Treat it as a still-evolving API surface: prefer `Mirror` for stable, ordinary reflection needs, and reach for `Reflection` only when the task specifically needs its structured type-level metadata (e.g. building generic serialization or diffing infrastructure).

```swift
import Reflection

// Illustrative shape only — consult current Reflection module docs
// for exact API names before depending on this in production code.
for field in try typeInfo(of: Point.self).fields {
    print(field.name, field.type)
}
```

Prefer static typing and protocols (`Codable`, `Equatable`, `CustomStringConvertible`) over reflection whenever the shape of the data is known at compile time — reflection is for genuinely dynamic/generic tooling, not a substitute for ordinary conformances.
