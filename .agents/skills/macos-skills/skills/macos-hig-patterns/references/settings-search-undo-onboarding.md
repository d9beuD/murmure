# Settings, Search, Undo/Redo, Onboarding, Launch, Loading, Media, Printing

## The Settings window

Build app preferences with SwiftUI's `Settings` scene, not a custom window — it gets the standard `⌘,` shortcut, appears under the app menu as "Settings…" (not "Preferences…" as of recent macOS versions), and behaves like every other Mac app's settings window. Group related preferences into tabs with `TabView`, each tab backed by a small icon and label; keep the window a fixed, modest size rather than a large resizable canvas.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        Settings {
            TabView {
                GeneralSettingsView()
                    .tabItem { Label("General", systemImage: "gear") }
                AdvancedSettingsView()
                    .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
            }
        }
    }
}
```

Keep each tab's content focused (General, Accounts, Advanced, etc.) and avoid burying a setting so deep it needs its own search; if the app has more than a handful of settings, add a search field at the top of the Settings window rather than growing the tab list.

## Searching

Attach search to the content it filters using `.searchable(text:)` on the enclosing `NavigationSplitView`/`NavigationStack` — this places the field in the standard location (top of the sidebar or toolbar) instead of a custom-positioned text field, so it's where users expect it on every screen. Filter live as the user types for in-memory content; debounce and show a subtle progress indicator for anything that hits disk or network.

```swift
NavigationSplitView {
    List(filteredItems) { item in Text(item.name) }
} detail: {
    DetailView()
}
.searchable(text: $query, placement: .sidebar, prompt: "Search Recipes")
```

For content with distinct categories, add search scopes (`.searchScopes`) rather than a separate scope picker control, and keep the "no results" state specific ("No recipes match “kale”") instead of a generic empty view.

## Undo and redo

Wire every meaningful, reversible user action through `UndoManager` rather than building bespoke "are you sure" confirmations or app-specific history stacks — Mac users expect `⌘Z`/`⇧⌘Z` (and Edit menu Undo/Redo items) to work everywhere, including in text fields, list reordering, and custom document edits. In SwiftUI, register actions on the environment's undo manager, don't create your own `UndoManager` instance when one is already supplied by the scene/document.

```swift
struct EditorView: View {
    @Environment(\.undoManager) private var undoManager
    @Binding var text: String

    func replace(with newText: String) {
        let oldText = text
        undoManager?.registerUndo(withTarget: self) { target in
            target.replace(with: oldText)
        }
        text = newText
    }
}
```

Give each undo action a descriptive name (`undoManager.setActionName("Rename Layer")`) so the Edit menu reads "Undo Rename Layer" instead of a generic "Undo" — this is a one-line call and meaningfully improves clarity. Reserve a confirmation alert for actions `UndoManager` can't cleanly reverse (permanent deletion from disk, sending an email) rather than adding a dialog on top of an already-undoable action.

## Onboarding

Keep onboarding lightweight and skippable: a single optional welcome screen at most, and prefer contextual coaching (a one-time popover the first time a feature is used) over a forced multi-step tutorial that blocks the main window. Never require the user to click through screens describing features before they can use the app — let them dismiss immediately and discover progressively.

```swift
.popover(isPresented: $showHintOnce, arrowEdge: .bottom) {
    Text("Drag files here to import them.")
        .padding()
}
```

Persist "seen" state (e.g. in `AppStorage`) so a hint or welcome screen never reappears once dismissed, and always include a clear, obvious way to skip or close it (an "×" or "Skip" — not just a "Next" that must be clicked through).

## Launching and loading

Optimize for the window being usable within roughly a second: defer expensive work (network calls, large file parsing, indexing) until after the first frame renders, and restore the user's last session (open documents, window positions, selected sidebar item) by default rather than starting from a blank state — macOS users expect quitting and relaunching to feel like nothing happened. Use SwiftUI's automatic scene restoration (`@SceneStorage`) for lightweight UI state like selection and scroll position.

For content that takes visible time to load, show a skeleton/placeholder that matches the eventual layout (rows, image bounds) rather than a blank screen or a single centered spinner — this improves perceived performance because the structure appears immediately even before data does.

```swift
if items.isEmpty && isLoading {
    List(0..<8, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 6).fill(.quaternary).frame(height: 44)
            .redacted(reason: .placeholder)
    }
} else {
    List(items) { ItemRow(item: $0) }
}
```

## Playing audio and video

Use `AVKit`'s `VideoPlayer` (SwiftUI) or `AVPlayerView` (AppKit) rather than a custom transport UI — it gives users the standard scrubber, fullscreen toggle, and Picture in Picture for free, and stays consistent with QuickTime Player and other system video surfaces. Never override or fight the system volume/mute state: respect the user's current output volume and the physical mute key rather than introducing a separate in-app volume control unless the app has a specific mixing need (e.g. a DAW), and even then keep it in addition to, not a replacement for, system volume.

```swift
VideoPlayer(player: player)
    .onAppear { player.play() }
```

## Printing

Use `NSPrintOperation` (AppKit) — SwiftUI has no direct print scene, so route through an `NSViewRepresentable`/`NSPrintOperation` or `NSPrintPanel` — and always show the standard print panel/preview so users can confirm paper size, orientation, and page range before committing rather than printing silently. Provide a page setup path (`NSPageLayout`) for documents where orientation/paper size genuinely varies, but don't surface printing UI at all for content that isn't meaningfully printable (e.g. a live chat view).

```swift
let printInfo = NSPrintInfo.shared
let operation = NSPrintOperation(view: printableView, printInfo: printInfo)
operation.showsPrintPanel = true
operation.run()
```
