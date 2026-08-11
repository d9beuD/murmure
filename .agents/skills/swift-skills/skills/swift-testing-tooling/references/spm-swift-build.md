# Swift Package Manager & Swift Build

## Minimal `Package.swift` structure

Every package needs `swift-tools-version`, a `name`, and at least one target; `products` expose targets to consumers, and targets not listed in any product stay internal (e.g. test-only helpers).

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Widgets",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "Widgets", targets: ["Widgets"])
    ],
    targets: [
        .target(name: "Widgets"),
        .testTarget(name: "WidgetsTests", dependencies: ["Widgets"])
    ]
)
```

Declare only the targets/products/dependencies the current task needs — don't add a product for a target nothing external consumes, and don't bump `platforms`/`swift-tools-version` higher than the feature in use requires.

## Executable targets and `swift run`

`.executableTarget` builds a runnable binary from a `main.swift` or a type marked `@main`; `swift run` builds (if needed) and runs it in one step.

```swift
targets: [
    .executableTarget(name: "widgets-cli", dependencies: ["Widgets"])
]
```

```bash
swift run widgets-cli --input file.txt
```

## Dependencies

External packages are declared once at the package level with a version requirement, then referenced by product name in each target that needs them.

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0")
],
targets: [
    .target(name: "Widgets", dependencies: [
        .product(name: "Collections", package: "swift-collections")
    ])
]
```

Use `.upToNextMajor(from:)` (the default for `from:`) unless the task specifically calls for pinning an exact version (`.exact("1.2.0")`) or a branch (`.branch("main")`, avoid for release code).

## Resources

Bundle non-code files with a target using `.copy` (preserves directory structure/name exactly) or `.process` (may transform, e.g. compile `.xcassets`); access them at runtime through `Bundle.module`.

```swift
targets: [
    .target(
        name: "Widgets",
        resources: [
            .copy("Fixtures/sample.json"),
            .process("Assets.xcassets")
        ]
    )
]
```

```swift
let url = Bundle.module.url(forResource: "sample", withExtension: "json")
```

## Build plugins

A `.plugin` target runs custom logic (code generation, linting) during `swift build`; attach it to a consuming target with `plugins:` and implement the plugin's entry point conforming to `BuildToolPlugin` or `CommandPlugin`.

```swift
targets: [
    .target(name: "Widgets", plugins: ["GenerateResourcesPlugin"]),
    .plugin(
        name: "GenerateResourcesPlugin",
        capability: .buildTool(),
        dependencies: ["GeneratorTool"]
    )
]
```

## `swift build`, `swift test`, `swift run`

```bash
swift build                       # build all targets, debug config
swift build -c release            # release configuration
swift build --target Widgets      # build one target
swift test                        # build and run all tests
swift test --filter WidgetsTests  # run a subset (see swift-testing.md)
swift run widgets-cli             # build (if needed) and execute
swift package resolve             # resolve/update Package.resolved without building
```

Read the first compiler error/failure in the output before making another change — don't re-run the same command hoping for a different result.

## Swift 6.3 preview: the Swift Build engine

Swift 6.3 bundles a preview of Swift Build (the unified engine Xcode already uses) as an alternative to SwiftPM's native build engine, giving one consistent engine across platforms. It is opt-in in 6.3 — the native engine stays the default — selected per invocation with `--build-system`.

```bash
swift build --build-system swiftbuild   # opt into the Swift Build preview engine
swift test  --build-system swiftbuild
swift build --build-system native       # explicit native engine (current default)
```

Only pass `--build-system swiftbuild` when the task specifically asks to try/validate the preview engine; keep using the native default for ordinary build/test requests, since some plugin and platform behavior may still differ under the preview engine.

## `Package.swift` conditionals and settings

Use `.when(platforms:configuration:)` to scope a dependency/setting instead of branching with `#if` inside `Package.swift`; use `swiftSettings`/`unsafeFlags` sparingly and only when a task explicitly needs a compiler flag or upcoming feature.

```swift
.target(
    name: "Widgets",
    dependencies: [
        .product(name: "Logging", package: "swift-log", condition: .when(platforms: [.linux]))
    ],
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny")
    ]
)
```

## Stop conditions for this file

- `Package.swift` declares exactly the targets/products/dependencies/resources the requested feature needs, nothing speculative.
- `swift build` (or `swift test`) succeeds with the native build system unless the task specifically asked to validate the Swift Build preview engine.
- No `unsafeFlags` or version pins were added without a concrete reason tied to the task.
