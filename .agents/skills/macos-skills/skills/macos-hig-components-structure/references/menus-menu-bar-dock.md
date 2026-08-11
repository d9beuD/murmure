# Menus, the Menu Bar, and the Dock Menu (macOS 26 Tahoe)

## Extend the menu bar with Commands, don't replace it

Add app menu bar items with `.commands { }` on the `App`/`Scene`, using `CommandGroup` to insert items relative to existing system menu items and `CommandMenu` to add a whole new top-level menu. Never try to hide or fully rebuild the standard App/File/Edit/View/Window/Help menus — only add to them.

```swift
@main
struct EditorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New From Template…") {
                    NotificationCenter.default.post(name: .newFromTemplate, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
    }
}
```

## CommandMenu for a new top-level menu

Use `CommandMenu` when the app has a coherent set of actions that don't belong under an existing menu (e.g., a "Format" or "Playback" menu). Give it a clear, single-word-where-possible title matching macOS conventions (Title Case, no trailing ellipsis on the menu title itself).

```swift
.commands {
    CommandMenu("Playback") {
        Button("Play/Pause") { player.toggle() }
            .keyboardShortcut(.space, modifiers: [])
        Button("Next Track") { player.next() }
            .keyboardShortcut(.rightArrow, modifiers: .command)
        Button("Previous Track") { player.previous() }
            .keyboardShortcut(.leftArrow, modifiers: .command)
    }
}
```

## CommandGroup for inserting into existing menus

Use `CommandGroup(before:)`/`CommandGroup(after:)`/`CommandGroup(replacing:)` to place items relative to system anchors like `.newItem`, `.saveItem`, `.undoRedo`, `.toolbar`, `.sidebar`, `.help`. Prefer `before`/`after` over `replacing` — replacing a standard group removes system-provided items (e.g., all of File > New) and usually isn't what's intended.

```swift
.commands {
    CommandGroup(after: .saveItem) {
        Button("Export as PDF…") { exportPDF() }
            .keyboardShortcut("e", modifiers: [.command, .shift])
    }
}
```

## Keyboard shortcuts: follow convention, never collide

Give every frequent menu command a keyboard shortcut using `.keyboardShortcut(_:modifiers:)`, following established conventions: Cmd+letter for primary actions, add Shift for a "more" variant of the same action (Save vs. Save As), Option for a finer-grained variant. Do not reassign shortcuts already owned by the system or by standard menus (Cmd-Q, Cmd-W, Cmd-,, Cmd-Z/Shift-Cmd-Z, Cmd-C/V/X, Cmd-A, Cmd-F) — check the standard menu conventions before picking a new one, and never assign the same shortcut to two different commands in the same app.

```swift
Button("Duplicate") { duplicateSelection() }
    .keyboardShortcut("d", modifiers: .command)

Button("Duplicate with Options…") { duplicateSelection(withOptions: true) }
    .keyboardShortcut("d", modifiers: [.command, .option])
```

## Contextual menus

Attach a `Menu` (or `.contextMenu { }`) to a view for secondary-click/Control-click actions that operate on that specific item — a row in a list, a canvas object. Keep the contents scoped to what's relevant to the clicked item, ordered with the most common action first, and mirror any destructive action's confirmation behavior from elsewhere in the app.

```swift
List(items) { item in
    Text(item.name)
        .contextMenu {
            Button("Rename") { rename(item) }
            Button("Duplicate") { duplicate(item) }
            Divider()
            Button("Delete", role: .destructive) { delete(item) }
        }
}
```

For a menu triggered from a visible button rather than secondary-click, use `Menu` directly:

```swift
Menu {
    Button("Sort by Name") { sortOrder = .name }
    Button("Sort by Date") { sortOrder = .date }
} label: {
    Label("Sort Options", systemImage: "arrow.up.arrow.down")
}
```

## The Dock menu

The Dock menu is the menu that appears when the user secondary-clicks (or clicks-and-holds) the app's Dock icon. In a SwiftUI-first app, populate it by adding commands conceptually equivalent to the app's most useful global actions — typically "New Window," recent-document shortcuts, or a small set of quick actions that make sense with no window open. SwiftUI does not expose a dedicated Dock-menu builder API directly; when the app needs custom Dock menu items beyond what the system supplies automatically (like "New Window" for a `WindowGroup`-based app), that customization happens at the `NSApplicationDelegate` level (`applicationDockMenu(_:)`), not through `.commands`. Keep this skill's scope to the SwiftUI structural side: make sure the actions you'd surface in the Dock menu already exist as ordinary menu-bar commands first, since the Dock menu should never offer an action unrelated to something already reachable from the menu bar.

```swift
// Menu bar command that should also be reachable from the Dock menu conceptually:
.commands {
    CommandGroup(after: .newItem) {
        Button("New Window") { openWindow(id: "main") }
            .keyboardShortcut("n", modifiers: .command)
    }
}
```

## Menu content rules

- Title menu items with verbs or short noun phrases in Title Case; no periods.
- Use a trailing ellipsis ("Export…") only when the action opens a sheet/dialog requiring more input before completing.
- Disable (don't hide) a menu item when its action is temporarily unavailable, so the menu's structure stays predictable.
- Group related items with `Divider()`; don't create a menu deeper than two submenu levels.
