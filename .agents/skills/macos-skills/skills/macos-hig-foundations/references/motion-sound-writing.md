# Motion, Sound, and Writing for macOS

## Motion: default to subtle

Mac interactions are mouse- and trackpad-driven at close range on a large, stationary screen, so motion should be quicker, smaller in scale, and more restrained than the equivalent iOS animation — a window or popover shouldn't perform a dramatic full-screen transition to reveal a menu. Use animation to clarify a state change (a sidebar collapsing, a row being deleted, a value updating), not as decoration; if removing the animation entirely would not confuse the user, it's probably unnecessary.

```swift
withAnimation(.easeInOut(duration: 0.2)) {
    isExpanded.toggle()
}
```

## Motion: purposeful, not gratuitous

Tie animation to a real state change and keep its duration short (roughly 0.15–0.3s for most UI transitions); longer or bouncier animations read as playful on iOS but as sluggish or unserious on the Mac. Avoid looping or attention-grabbing animations (pulsing icons, continuous shimmer) outside of an explicit, temporary loading indicator such as `ProgressView`.

```swift
ProgressView("Indexing…")
    .progressViewStyle(.linear)
```

## Motion: respect Reduce Motion

Check the `accessibilityReduceMotion` environment value and substitute a simple cross-fade or instant state change for anything more elaborate (parallax, large-scale movement, spring bounce) when it's enabled. Never make an animation load-bearing — the same information must be conveyed if the animation is skipped entirely.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

withAnimation(reduceMotion ? .linear(duration: 0.01) : .spring) {
    showDetail = true
}
```

## Motion: window and view transitions

Prefer the system's own window/sheet/popover presentation animations over custom transitions — `sheet`, `popover`, and `NavigationSplitView` already animate correctly for the platform, including for Liquid Glass surfaces in macOS 26. When you do need a custom transition (e.g., swapping detail content), use a simple `.opacity`/`.move` combination rather than 3D flips, elaborate morphs, or bounce effects that are out of place on the Mac.

```swift
detailContent
    .transition(.opacity.combined(with: .move(edge: .trailing)))
```

## Sound: use sparingly and only for meaningful events

macOS apps use sound far less than iOS apps; reserve a sound for something the user needs to notice even when not looking at the screen — a completed long-running task, an error, an incoming notification — never for routine feedback like a button press, a keystroke, or a successful save. When in doubt, ship without sound and add it only if user feedback indicates it's needed.

```swift
NSSound(named: "Funk")?.play()
```

## Sound: respect system settings and provide a visual equivalent

Every sound cue must have a visual counterpart (an icon, a banner, a state change) so the app remains fully usable with the system volume muted or with sound effects disabled; do not gate any functional information behind audio alone. Prefer a standard system sound over a custom one, and never loop a sound or play it repeatedly for an ongoing state.

## Writing: capitalization conventions

Use title case for command-like UI text a user acts on directly — button titles, menu items, tab labels, alert action buttons ("Save As…", "Move to Trash", "Don't Save") — and sentence case for explanatory text, body copy, field labels, and help text ("Choose a folder to save your files in."). Don't apply title case to full sentences or descriptive labels; it reads as shouted or old-fashioned on macOS.

```swift
Button("Empty Trash") { emptyTrash() }
Text("Emptying the Trash frees up disk space.")
```

## Writing: terminology

Use Mac-native terms consistently with the rest of the system: "Quit" (not "Exit"), "Preferences" or "Settings" per current system naming, "Trash" (not "Recycle Bin"), "folder" (not "directory") in user-facing text, and "click" for mouse/trackpad activation (reserve "tap" for touch-driven surfaces like iPhone/iPad, not Mac). Match the exact wording Apple uses in System Settings and Finder for concepts you share with the system, rather than inventing new phrasing for the same idea.

## Writing: microcopy and tone

Address the user directly and simply ("You can change this later in Settings") rather than in passive or technical voice ("This setting may be modified subsequently"). Keep labels and alert messages short and specific about what happened and what the user can do next; avoid exclamation points, avoid exposing raw error codes or stack traces in user-facing text, and avoid redundant words already implied by context (a button inside a "Delete Item?" alert doesn't need to repeat "item").

```swift
.alert("Delete “\(item.name)”?", isPresented: $showDeleteAlert) {
    Button("Delete", role: .destructive) { delete(item) }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This item will be moved to the Trash.")
}
```

## Writing: window titles and menu labels

Give every window a specific, descriptive title (a document name, not just the app name) so Mission Control, the Window menu, and Cmd-\` cycling stay usable with several windows open. Menu item labels should name the action, not describe a state ("Show Sidebar" / "Hide Sidebar" as the label toggles, rather than a static "Toggle Sidebar"), and should use standard modifier-key symbols and an ellipsis ("Export…") only when the command opens a dialog requiring more input before completing.

```swift
.navigationTitle(document.displayName)
```

## Privacy by design

Collect only the data a feature genuinely needs, and ask for a permission (camera, contacts, location, file access) at the moment the feature that needs it is actually used, not at launch. Explain in plain language, in the system permission prompt's purpose string, why the access is needed; prefer doing processing on-device and scoping file access narrowly (e.g., an `NSOpenPanel`-granted security-scoped bookmark) over requesting broad entitlements like full-disk access when a narrower one will do.

```swift
// Info.plist purpose string, shown in the system permission prompt
// NSCameraUsageDescription: "Used to scan documents you add to your library."
```
