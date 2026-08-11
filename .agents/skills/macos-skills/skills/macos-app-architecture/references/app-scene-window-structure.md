# App, Scene, and Window Structure

## The App protocol and @main

Every SwiftUI app has exactly one type conforming to `App`, marked `@main`, whose `body` returns one or more `Scene`s. This replaces `NSApplicationMain`/`AppDelegate` as the app's entry point on macOS 26.

```swift
@main
struct NotesApp: App {
    @State private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
```

Top-level `@State` in the `App` struct is the natural place to own app-wide models that outlive any single window; inject them into scenes with `.environment(_:)`.

## WindowGroup for document-like or repeatable windows

`WindowGroup` declares a scene the user can open multiple instances of (File > New Window). Each instance gets its own view identity and state.

```swift
WindowGroup("Note", id: "note-editor", for: Note.ID.self) { $noteID in
    NoteEditorView(noteID: noteID)
}
```

Use the `for:` initializer to make each window's content parameterized by a value type (an ID, a URL); SwiftUI restores the right window on relaunch when the value is `Codable`.

## Window for a single, unique window

`Window` declares exactly one instance of a scene — no New Window duplication. Good for an inspector, a dashboard, or any window that only ever exists once.

```swift
Window("Inspector", id: "inspector") {
    InspectorView()
}
.defaultSize(width: 320, height: 480)
```

Open or focus it programmatically with `openWindow(id:)` from `@Environment(\.openWindow)`, and dismiss with `dismissWindow(id:)`.

## Settings scene

`Settings` provides the standard macOS Settings/Preferences window, wired automatically into the app menu and the ⌘, shortcut.

```swift
Settings {
    SettingsView()
        .environment(preferences)
}
```

Don't build a Settings window as a plain `WindowGroup` — using `Settings` gets you the correct menu item, shortcut, and single-instance behavior for free.

## DocumentGroup for document-based apps

`DocumentGroup` wires up NSDocument-style open/save/undo behavior for apps built around user-created files, backed by a `FileDocument` or `ReferenceFileDocument`.

```swift
struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String = ""

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(decoding: data, as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

DocumentGroup(newDocument: TextFile()) { config in
    TextEditorView(document: config.$document)
}
```

Use `ReferenceFileDocument` instead of `FileDocument` when the document is a reference type (e.g. an `@Observable` class) rather than a value type — it integrates with `UndoManager` more naturally for class-based models.

## MenuBarExtra for menu bar apps

`MenuBarExtra` puts a persistent item in the menu bar, with either a dropdown `menu` style or a custom SwiftUI `window` style popover.

```swift
MenuBarExtra("Status", systemImage: "bolt.fill") {
    StatusMenuView()
}
.menuBarExtraStyle(.window)
```

`.menuBarExtraStyle(.menu)` (the default) gives you a traditional NSMenu-like list of buttons; `.window` gives you a floating panel that can host arbitrary SwiftUI content, including controls and images, not just menu items.

## Combining multiple scenes in one App

An `App`'s `body` can return several scenes as a `Group`-like composition; SwiftUI treats each as an independent top-level scene contributing to the app's menu and window list.

```swift
var body: some Scene {
    WindowGroup { ContentView() }
    Settings { SettingsView() }
    MenuBarExtra("Quick Actions", systemImage: "star") { QuickActionsView() }
}
```

Each scene type contributes its own default menu commands (New Window for `WindowGroup`, Preferences… for `Settings`); use `.commands { }` on a scene to add or replace menu items instead of hand-building `NSMenu`.

## Scene-level modifiers

`.defaultSize`, `.defaultPosition`, `.windowResizability`, and `.windowStyle` configure how a scene's windows initially appear, applied to the scene, not the inner view.

```swift
WindowGroup {
    ContentView()
}
.windowResizability(.contentSize)
.defaultSize(width: 800, height: 600)
```

`.windowResizability(.contentSize)` lets SwiftUI size the window to fit content and constrains resizing to the content's ideal/min/max, which is usually preferable to a fixed pixel size for text-heavy windows.

## Opening and dismissing windows programmatically

Use the `openWindow` and `dismissWindow` environment actions rather than reaching for `NSWindow` APIs directly.

```swift
struct ToolbarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Inspector") { openWindow(id: "inspector") }
    }
}
```

This keeps window lifecycle fully in SwiftUI's hands; only fall back to `NSWindow`/`NSWindowController` (see appkit-interop.md) for behavior SwiftUI's scene APIs genuinely can't express, such as custom window chrome tricks.
