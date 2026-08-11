# Windows, Panels, Sheets, and Popovers (macOS 26 Tahoe)

## WindowGroup for document- and instance-based content

Use `WindowGroup` when the user can have multiple independent instances of the same content (documents, notes, projects). Each instance gets its own window and, where applicable, its own state restoration entry. Give the app's main window a stable, descriptive title — macOS shows it in the title bar, Window menu, Mission Control, and Dock menu.

```swift
@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup("Note", id: "note", for: Note.ID.self) { $noteID in
            NoteDetailView(noteID: noteID)
        }
        .defaultSize(width: 640, height: 480)
    }
}
```

## Window for singleton windows

Use `Window` (not `WindowGroup`) for a window that should only ever have one instance — a settings-adjacent utility window, a dashboard, a single-instance browser-style window. Combine with `.defaultSize` and `.frame` min/ideal constraints so the window opens at a sensible size but stays resizable within reason.

```swift
Window("Activity Monitor", id: "activity") {
    ActivityMonitorView()
        .frame(minWidth: 480, idealWidth: 720, minHeight: 320)
}
.defaultSize(width: 720, height: 480)
```

Set realistic `minWidth`/`minHeight` so content never clips; avoid forcing a fixed size unless the window's content is genuinely non-resizable (e.g., a small utility HUD).

## Window restoration

Let SwiftUI's default window restoration work by giving windows and `WindowGroup` scenes stable, unique `id`s and by keeping model state `Codable`/restorable where you rely on system restoration. Don't hand-roll restoration logic unless the default behavior is insufficient — that adds state to track and more ways to loop on bugs.

## Title bar and toolbar styling

Use `.windowStyle(.titleBar)` (the default) for standard document/app windows, and `.windowStyle(.hiddenTitleBar)` only when the content itself provides its own chrome (e.g., a full-bleed media player). Pair with `.windowToolbarStyle(.unified)` or `.unifiedCompact` to match the modern macOS look where the toolbar sits flush with the title bar; use `.expanded` sparingly for toolbars with many grouped controls.

```swift
WindowGroup {
    PlayerView()
}
.windowStyle(.hiddenTitleBar)
.windowToolbarStyle(.unifiedCompact)
```

Do not hide the title bar just to save vertical space in an ordinary content window — HIG expects the title bar for window dragging, the Window menu proxy icon, and full-screen/tiling affordances.

## Utility and inspector panels

For auxiliary controls that stay visible alongside a document (color pickers, format inspectors, layer lists), prefer the `.inspector()` modifier over building a separate floating window. It gives a trailing (or leading) panel that the user can show/hide and resize, consistent with apps like Pages and Keynote.

```swift
struct EditorView: View {
    @State private var showInspector = true

    var body: some View {
        DocumentCanvas()
            .inspector(isPresented: $showInspector) {
                InspectorContent()
                    .inspectorColumnWidth(min: 220, ideal: 260, max: 340)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("Inspector", systemImage: "sidebar.trailing")
                    }
                }
            }
    }
}
```

Reserve a true floating utility panel (conceptually an `NSPanel` — nonactivating, stays above the main window, HUD-style) for tool palettes that must remain visible while the user works in the main window (e.g., a color palette or a small find bar). In SwiftUI-first apps this is a narrower `Window` scene with a compact `.frame`; don't reach for `NSPanel` directly unless you need nonactivating/HUD behavior SwiftUI doesn't expose.

## Sheets for focused, blocking tasks

Use `.sheet(isPresented:)` (or the item-based variant) when the user must complete or explicitly cancel a single, focused task before returning to the underlying window — exporting, configuring a new item, entering required details. A sheet is app-modal to its window only, so the user can still work in other windows.

```swift
struct DocumentView: View {
    @State private var isExporting = false

    var body: some View {
        ContentView()
            .toolbar {
                ToolbarItem {
                    Button("Export…") { isExporting = true }
                }
            }
            .sheet(isPresented: $isExporting) {
                ExportOptionsView()
                    .frame(minWidth: 420, minHeight: 320)
            }
    }
}
```

Keep sheet content scoped to the one task with clear confirm/cancel actions; don't nest a second sheet on top of a sheet, and don't use a sheet for content the user might want to reference while continuing other work — that's a panel or window instead.

## Popovers for transient, contextual content

Use `.popover(isPresented:)` for lightweight, contextual content anchored to a specific control — a color swatch, a quick-look preview, a small settings flyout triggered from a toolbar button. Popovers dismiss automatically when the user clicks outside them, which makes them wrong for anything requiring a confirmed choice.

```swift
struct ColorButton: View {
    @State private var showPicker = false
    @Binding var color: Color

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Circle().fill(color).frame(width: 20, height: 20)
        }
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            ColorPicker("Color", selection: $color)
                .padding()
                .frame(width: 240)
        }
    }
}
```

Pick `arrowEdge` to point at the triggering control (`.bottom` for a toolbar button, `.leading`/`.trailing` for sidebar rows) and size popover content explicitly with `.frame` — unbounded popovers can render awkwardly small or large depending on content.

## Choosing among panel, sheet, and popover

- Content the user references while still interacting elsewhere → inspector panel or utility window.
- A single task that must be completed or dismissed before returning → sheet.
- A quick, anchored, low-commitment glance or micro-editor → popover.

If you're deciding at the *behavioral* level (e.g., "should this even be modal?") rather than which SwiftUI container to use, check macos-hig-patterns instead.
