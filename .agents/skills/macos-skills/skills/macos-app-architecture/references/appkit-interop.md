# AppKit Interop

## When to drop to AppKit at all

Only use AppKit when SwiftUI has no equivalent API: certain `NSApplicationDelegate` callbacks (dock menu, restoring windows, opening files from Finder), fine-grained `NSTextView`/`NSScrollView` behavior, custom `NSWindow` chrome/behavior, or wrapping a third-party AppKit-only control. Check the SwiftUI docs for a native API first — most "I need AppKit for this" assumptions on macOS 26 are out of date.

## NSViewRepresentable for wrapping an NSView

`NSViewRepresentable` bridges a single `NSView` into SwiftUI; implement `makeNSView`, `updateNSView`, and optionally a `Coordinator` for delegate callbacks.

```swift
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.load(URLRequest(url: url))
    }
}
```

`updateNSView` runs on every SwiftUI update where this view's inputs might have changed — keep it idempotent (don't reload/reset things that haven't actually changed).

## Coordinator for AppKit delegate patterns

When the wrapped `NSView` uses a delegate protocol, use `makeCoordinator()` to bridge delegate callbacks back into SwiftUI state.

```swift
struct SearchField: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { self._text = text }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text = field.stringValue
        }
    }
}
```

The `Coordinator` is the object that actually conforms to AppKit delegate protocols (`NSObject` subclass); it holds a `Binding` back to SwiftUI state so delegate callbacks can write through it.

## NSViewControllerRepresentable for wrapping an NSViewController

Use `NSViewControllerRepresentable` when the AppKit side is naturally a controller (owns its own view, lifecycle, and child controllers) rather than a bare view.

```swift
struct QuickLookRepresentable: NSViewControllerRepresentable {
    let url: URL

    func makeNSViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateNSViewController(_ nsViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewPanelDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        // QLPreviewController data source methods…
    }
}
```

Same shape as `NSViewRepresentable` — `make`/`update` pair plus an optional `Coordinator` — just for controller-owned AppKit APIs.

## NSHostingView and NSHostingController for embedding SwiftUI in AppKit

Going the other direction — putting SwiftUI content inside an existing AppKit app — use `NSHostingController` (view-controller-based) or `NSHostingView` (raw view) to host a SwiftUI hierarchy.

```swift
let hostingController = NSHostingController(rootView: SettingsView().environment(preferences))
window.contentViewController = hostingController
```

```swift
let hostingView = NSHostingView(rootView: BadgeView(count: 3))
someAppKitContainerView.addSubview(hostingView)
```

Set `rootView` again to push new SwiftUI content/state into an already-hosted controller; don't recreate the `NSHostingController` just to update its content.

## NSApplicationDelegateAdaptor for AppKit delegate callbacks

`@NSApplicationDelegateAdaptor` attaches a plain `NSApplicationDelegate` to a SwiftUI `App`, for the handful of callbacks SwiftUI's `Scene`/`App` APIs don't expose directly.

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Note", action: #selector(newNote), keyEquivalent: "n"))
        return menu
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Handle files opened from Finder / drag-onto-dock-icon.
    }

    @objc func newNote() { /* … */ }
}

@main
struct App_: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

Common reasons to reach for this: the dock menu (`applicationDockMenu`), opening files dragged onto the dock icon or double-clicked in Finder (`application(_:open:)`), reacting to `applicationDidFinishLaunching`/`applicationWillTerminate` for setup/teardown, or `applicationShouldTerminate` to intercept quit. Communicate between the delegate and SwiftUI state through an injected `@Observable` model, not by having the delegate reach into view internals.

## Passing shared state into the AppKit delegate

Give the delegate a reference to the same `@Observable` model the SwiftUI side uses, so delegate callbacks can drive the same source of truth.

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    var session: UserSession?

    func applicationDidFinishLaunching(_ notification: Notification) {
        session?.restoreLastSession()
    }
}

@main
struct App_: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = UserSession()

    var body: some Scene {
        WindowGroup { RootView().environment(session) }
            .onChange(of: session) { appDelegate.session = session }
    }
}
```

Wire the reference once near app startup (e.g. in the `App`'s initializer or an early `.task`) rather than reaching from the delegate back into the view hierarchy to find it.

## Deciding representable vs. full AppKit window

If only a small piece of UI needs an AppKit capability, wrap just that piece with `NSViewRepresentable`/`NSViewControllerRepresentable` inside an otherwise-SwiftUI window; don't drop an entire screen to AppKit for one missing control. Reserve `NSHostingController`-in-`NSWindow` for cases where the window itself must be AppKit-managed (e.g. a legacy `NSWindowController` subclass or a panel type SwiftUI's `Scene` APIs can't express).
