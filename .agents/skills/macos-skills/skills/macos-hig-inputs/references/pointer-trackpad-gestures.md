# Pointer and Trackpad Gestures

Guidance for mouse and trackpad interactions on macOS 26 Tahoe: click semantics, hover, scroll, and gestures.

## Primary vs. secondary click

Primary click (left mouse button, or single-finger tap/click on trackpad) performs an item's main action — opening, selecting, activating a control. Secondary click (right mouse button, two-finger click on trackpad, or Control-click) always opens a contextual menu — never a different destructive or navigational action:

```swift
Text(item.name)
    .contextMenu {
        Button("Rename") { rename(item) }
        Button("Delete", role: .destructive) { delete(item) }
    }
```

Don't hide a control's only way to perform an action behind secondary click — every context-menu action should also be reachable through a visible menu, toolbar item, or keyboard shortcut.

## Hover states with `.onHover`

Use hover to reveal supplementary controls or information (delete buttons on a row, a preview, a tooltip) — never to reveal something required to complete a task, since hover doesn't exist on touch-only or keyboard-only paths:

```swift
struct RowView: View {
    @State private var isHovering = false

    var body: some View {
        HStack {
            Text(title)
            if isHovering {
                Button("Remove", action: remove)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
```

Pair any hover-revealed action with a keyboard/menu equivalent so Full Keyboard Access users aren't blocked.

## Scroll behavior

Let content scroll natively with `ScrollView` rather than building custom scroll handling; respect the system's scroll direction and momentum settings:

```swift
ScrollView {
    LazyVStack(alignment: .leading) {
        ForEach(items) { item in
            RowView(item: item)
        }
    }
}
```

Reserve scroll-triggered actions (like lazy loading more items) for content that naturally scrolls — don't repurpose scroll gestures for unrelated commands such as navigation or zoom outside of a canvas/image context.

## Trackpad gestures: swipe to navigate

Support the system convention of a two-finger swipe (left/right) for back/forward navigation in any view that has a navigation history, matching Safari and Finder:

```swift
NavigationStack(path: $path) {
    DetailView()
}
// Back/forward swipe navigation is provided automatically by NavigationStack
// when embedded in the standard navigation chrome; avoid overriding it with
// a custom gesture recognizer unless building a non-standard paged UI.
```

If you must implement custom paging (e.g., a document viewer), use `.gesture(DragGesture())` deliberately and keep the swipe direction consistent with system expectations (swipe left = go forward/next).

## Trackpad gestures: pinch to zoom

Support pinch-to-zoom wherever content can meaningfully scale (images, PDFs, canvases, maps) using `MagnifyGesture` or `MagnificationGesture`, and always pair it with a keyboard/menu zoom alternative (⌘+ / ⌘-):

```swift
struct ZoomableImage: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image("diagram")
            .scaleEffect(scale)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in scale = value.magnification }
            )
            .keyboardShortcut("+", modifiers: .command)
    }
}
```

## Force click

Force click (a firmer press on Force Touch trackpads) triggers system-level lookups — Dictionary/Spotlight preview on a word, Quick Look on a file — via `NSPressureConfiguration`/AppKit hooks, not a SwiftUI gesture. Treat it as an OS-provided bonus interaction: never make it the only way to reach a piece of information, and don't attach custom actions to it that shadow the system's built-in force-click behaviors (like Look Up).

## Multi-select in lists

Support standard multi-select conventions in `List` — ⌘-click to toggle individual items, ⇧-click to select a contiguous range — by binding selection to a `Set`:

```swift
struct ItemList: View {
    @State private var selection = Set<Item.ID>()

    var body: some View {
        List(items, selection: $selection) { item in
            Text(item.name)
        }
    }
}
```

Ensure ⌘A (Select All) and Delete/Backspace (remove selection) work wherever multi-select is offered, matching Finder's list behavior.

## Bridge to accessibility

Any pointer-only or trackpad-only interaction (hover reveal, secondary click, pinch, swipe) must have a keyboard-reachable equivalent so it works under Full Keyboard Access, Switch Control scanning, and VoiceOver's rotor navigation. Implementing the VoiceOver labels and rotor actions themselves belongs to macos-best-practices — this skill only requires that an equivalent path exists.
