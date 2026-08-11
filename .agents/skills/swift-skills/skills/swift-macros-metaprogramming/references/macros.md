# Swift Macros

Macros run at compile time and expand into Swift source. Swift 6.3 supports two shapes: freestanding (`#name`) and attached (`@Name`), both backed by a SwiftSyntax macro plugin.

## Freestanding macro declaration and use

A freestanding macro is invoked with `#` and behaves like a function-call-shaped piece of syntax that expands into an expression, declaration, or statement. The declaration links a call-site signature to an external plugin type via `#externalMacro`.

```swift
@freestanding(expression)
macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(
    module: "MyMacroPlugin",
    type: "StringifyMacro"
)

let (result, code) = #stringify(2 + 3)
// code == "2 + 3", result == 5
```

Built-in freestanding macros ship with the compiler/toolchain and need no plugin: `#warning("message")` and `#error("message")` emit diagnostics at compile time, and `#Preview { ... }` (Xcode/SwiftUI tooling) registers a preview without a plugin of your own.

```swift
#if DEBUG
#warning("Remove temporary auth bypass before release")
#endif
```

## Attached macro declaration and roles

Attached macros are written `@Name` on a declaration and must declare one or more roles (`member`, `peer`, `accessor`, `extension`, `conformance`) describing what kind of code they may add. `@attached(member)` lets a macro add new members to the type it's attached to; `@attached(accessor)` lets it turn a stored property into one with a getter/setter; `@attached(extension)` lets it add an extension (often used to add protocol conformances).

```swift
@attached(member, names: named(init))
@attached(extension, conformances: Codable)
public macro AddCodableInit() = #externalMacro(
    module: "MyMacroPlugin",
    type: "AddCodableInitMacro"
)

@AddCodableInit
struct User {
    var id: Int
    var name: String
}
```

The `names:` argument declares in advance which identifiers the macro may introduce (`named(init)`, `arbitrary`, `overloaded`, etc.) — the compiler enforces this so expansion stays predictable and tooling can see intent without running the macro.

## Recognizing `@Observable`

`@Observable` (Swift Observation framework) is an attached macro combining `member` and `conformance` roles: it rewrites each stored property to track reads/writes for observation and makes the type conform to `Observable`, without you writing `@Published`-style wrappers.

```swift
import Observation

@Observable
final class CartModel {
    var items: [String] = []
    var total: Double = 0
}
// Expands to add an `_$observationRegistrar`, access/withMutation
// tracking per property, and `: Observable` conformance.
```

Treat `@Observable` (and similarly `@Model` in SwiftData, `@AddCodableInit`-style codegen macros) as consumed, not authored — reach for the reference implementation only when no existing macro covers the boilerplate.

## Minimal macro implementation with SwiftSyntax

A macro implementation is a separate compiler-plugin target that conforms to a role protocol from `SwiftSyntaxMacros` (`ExpressionMacro`, `MemberMacro`, `AccessorMacro`, `PeerMacro`, `ExtensionMacro`, `ConformanceMacro`). Each protocol requires an `expansion` static method receiving the call-site syntax node and a `MacroExpansionContext` for diagnostics and unique-name generation.

```swift
import SwiftSyntax
import SwiftSyntaxMacros

public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            throw MacroExpansionErrorMessage("stringify requires one argument")
        }
        return "(\(argument), \(literal: argument.description))"
    }
}
```

`MemberMacro` expansion instead returns `[DeclSyntax]` (new members to insert), and `ExtensionMacro` returns `[ExtensionDeclSyntax]`. The plugin target registers its macro types through a `CompilerPlugin` (`@main struct MyMacroPlugin: CompilerPlugin { let providingMacros: [Macro.Type] = [StringifyMacro.self] }`), declared in `Package.swift` as a `.macro` target consumed by a library target.

## When to author vs. consume

Prefer an existing macro (`@Observable`, `@Model`, testing macros, generated `Codable`/`Equatable` conformances) whenever one already produces the needed boilerplate — authoring a macro means adding a `SwiftSyntax` dependency, a separate compiler-plugin target, and expansion tests, which is justified only for genuinely repeated, mechanical boilerplate across a codebase. Diagnose expansion failures by checking the declared role/`names:` list first; a "cannot find X in scope" after expansion usually means the macro produced a name it never declared.
