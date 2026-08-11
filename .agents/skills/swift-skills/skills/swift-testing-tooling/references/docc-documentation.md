# DocC Documentation Comments

## Basic `///` doc comments

A `///` line (or `/** ... */` block) directly above a declaration becomes its documentation; the first line/paragraph is the summary shown in Quick Help and symbol lists, so keep it one concise sentence.

```swift
/// Withdraws `amount` from the account balance.
///
/// Use this instead of mutating `balance` directly so the account can
/// enforce the overdraft rule in one place.
func withdraw(_ amount: Decimal) throws {
    guard amount <= balance else { throw AccountError.insufficientFunds }
    balance -= amount
}
```

## `- Parameter`, `- Parameters`, `- Returns`, `- Throws`

Document each parameter, the return value, and any thrown errors with the matching field list item — only add these when the signature isn't already self-evident from names/types.

```swift
/// Fetches a decoded value of type `T` from the given URL.
///
/// - Parameters:
///   - url: The location to fetch from.
///   - decoder: The decoder used to parse the response body.
/// - Returns: The decoded value.
/// - Throws: `URLError` if the request fails, or a `DecodingError`
///   if the response body doesn't match `T`.
func fetch<T: Decodable>(from url: URL, decoder: JSONDecoder = .init()) async throws -> T {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try decoder.decode(T.self, from: data)
}
```

For a single parameter, `- Parameter name:` (singular) is equivalent to a one-entry `- Parameters:` list.

```swift
/// - Parameter id: The unique identifier to look up.
func user(id: Int) -> User? { users[id] }
```

## Markdown in doc comments

Doc comments support standard Markdown — inline code, lists, and links — rendered by DocC and Quick Help; use backticks for symbol/parameter names and fenced code blocks for usage examples.

```swift
/// A thread-safe cache keyed by `String`.
///
/// Typical usage:
/// ```swift
/// let cache = Cache<Data>()
/// cache.set(data, for: "profile")
/// ```
///
/// - Note: Reads and writes are safe to call concurrently.
/// - Warning: Values are evicted with no notice under memory pressure.
struct Cache<Value> { }
```

## Linking to other symbols

Double-backtick syntax (` ``Symbol`` `) creates a link to another documented symbol in the same module or an imported one; use the qualified form for overloaded or ambiguous names.

```swift
/// See ``Account/withdraw(_:)`` for the paired deposit-side operation.
func deposit(_ amount: Decimal) { balance += amount }
```

## Documentation catalogs and curation

A `.docc` catalog in a target adds hand-written articles/tutorials and top-level curation on top of in-source comments; the catalog's root `.md` file's title must match the module name to become the landing page.

```
Sources/Widgets/Widgets.docc/
├── Widgets.md          // landing page, title "# ``Widgets``"
└── GettingStarted.md    // extra article, linked via a Topics list
```

```markdown
# ``Widgets``

A lightweight widget-rendering library.

## Topics

### Essentials
- ``Widget``
- ``WidgetRenderer``
```

## Generating documentation

`swift package generate-documentation` (from the `swift-docc-plugin`) builds a `.doccarchive` from source comments plus any `.docc` catalog; add the plugin as a dependency once per package.

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0")
]
```

```bash
swift package generate-documentation --target Widgets
swift package generate-documentation --target Widgets --output-path ./docs
swift package --disable-sandbox preview-documentation --target Widgets   # local live preview
```

## Stop conditions for this file

- Every newly added/edited public declaration has a one-line summary and, if its signature isn't self-evident, `- Parameter(s)`/`- Returns`/`- Throws`.
- Doc comments describe behavior and constraints, not a restatement of the function name.
- `swift package generate-documentation` (only if the task asked to generate/preview docs) completes without warnings about missing/broken symbol links.
