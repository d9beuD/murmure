# Performance & Testing (macOS 26 Tahoe / Xcode 26)

## Instruments basics

Profile with **Product > Profile** (Cmd-I) or `xcrun xctrace` to launch Instruments against a Release-like build; don't trust Debug-build timings for perf decisions.

```bash
# Record a Time Profiler trace from the command line
xcrun xctrace record --template 'Time Profiler' \
  --launch -- /Applications/MyApp.app/Contents/MacOS/MyApp \
  --output ~/Desktop/MyApp.trace
```

Start with the **Time Profiler** instrument to find hot call stacks, and the **SwiftUI** instrument (View Body counts, "Update Groups") to spot views that re-render more often than expected. Symbolicate against a build with debug symbols so the call tree shows real function names.

## Avoiding main-thread blocking work

Move file I/O, JSON parsing, image decoding, and network calls off the main actor; use `Task` with an actor or `Task.detached` for CPU-bound work, and only hop back to the main actor to update UI state.

```swift
@MainActor
final class ReportViewModel: ObservableObject {
    @Published var rows: [ReportRow] = []

    func load(url: URL) async {
        let parsed = await Task.detached(priority: .userInitiated) {
            try? Self.parse(contentsOf: url)
        }.value
        rows = parsed ?? []
    }

    nonisolated static func parse(contentsOf url: URL) throws -> [ReportRow] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ReportRow].self, from: data)
    }
}
```

Watch for accidental main-thread work hiding in synchronous property getters (e.g., computing a formatted string from a large array inside `body`) — Instruments' Time Profiler with the main thread filtered in will surface these as spikes during scrolling or typing.

## List/Table performance with large datasets

`List` and `Table` are already lazy (they only materialize visible rows), so most slowdowns come from expensive work happening *inside* each row's `body` or from identity churn. Give rows a stable, cheap `id`, and precompute formatted strings/derived values before they reach the view.

```swift
struct ContentView: View {
    let items: [Item] // pre-sorted / pre-filtered off the main thread

    var body: some View {
        Table(items) {
            TableColumn("Name", value: \.name)
            TableColumn("Size") { item in
                Text(item.formattedSize) // precomputed, not computed per-render
            }
        }
    }
}
```

For datasets in the tens of thousands, page/filter the underlying array (e.g., fetch in batches, or back the list with `NSFetchedResultsController`/a paged query) rather than binding the full collection into a `@State`/`@Published` array that re-diffs on every mutation.

## Swift Testing for macOS

Swift Testing (`import Testing`) is the current default for new unit tests in Xcode 26; use `@Test` and `#expect`/`#require` instead of XCTest's `XCTAssert*` family for new test targets.

```swift
import Testing
@testable import MyApp

@Test func discountAppliesOnlyAboveThreshold() {
    let cart = Cart(items: [Item(price: 40)])
    #expect(cart.total(withDiscountThreshold: 50) == 40)

    cart.add(Item(price: 20))
    #expect(cart.total(withDiscountThreshold: 50) < 60)
}

@Test(arguments: [0, 1, 5, 100])
func nonNegativeQuantityNeverThrows(quantity: Int) throws {
    #expect(throws: Never.self) {
        try Cart.validate(quantity: quantity)
    }
}
```

XCTest still applies for existing suites and for UI automation (`XCUIApplication`) — the two frameworks coexist in the same test plan.

## XCUIApplication UI tests

UI tests launch the app in a separate process and drive it through the accessibility tree, so controls need the same labels/identifiers accessibility relies on.

```swift
import XCTest

final class MainWindowUITests: XCTestCase {
    func testSavingDocumentEnablesShareButton() throws {
        let app = XCUIApplication()
        app.launch()

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.click()

        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 2))
        XCTAssertTrue(shareButton.isEnabled)
    }
}
```

Prefer `app.buttons["Save"]` (matched by accessibility label/identifier) over coordinate-based clicks, and use `.waitForExistence(timeout:)` instead of `sleep` to avoid flaky tests. Set `.accessibilityIdentifier("saveButton")` on ambiguous controls when the visible label alone isn't a reliable unique match.
