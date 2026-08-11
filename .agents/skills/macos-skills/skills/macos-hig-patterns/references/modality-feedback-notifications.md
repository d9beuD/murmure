# Modality, Feedback, and Notifications

## The modality decision tree

Before adding any new modal surface, decide which of four things it actually is:

1. **Alert** — the user must make a decision or acknowledge something before doing anything else, and the message is short (one or two sentences plus at most a couple of buttons). Use SwiftUI's `.alert(_:isPresented:actions:)`. Reserve alerts for errors that block progress and for destructive confirmations that can't be undone cheaply.
2. **Sheet** — a self-contained task that's scoped to one document/window and blocks only that window (not the whole app). Use `.sheet(isPresented:)` for things like "Export," "New Project Settings," or a multi-field editor the user finishes and dismisses. Sheets are the default choice for "do one focused thing, then come back."
3. **Panel** — non-modal, persistent, floats above the main window (inspectors, color pickers, find bars, tool palettes). Use `NSPanel` (SwiftUI has no first-class panel API yet, so wrap AppKit) with `.nonactivatingPanel` style when the user should be able to keep working in the main window while the panel stays visible.
4. **Separate window** — an independent task or document that the user may want to keep open alongside others, compare side by side, or leave running unattended. Use a second `WindowGroup`/`Window` scene, not a giant sheet, when the content deserves its own lifecycle (resizable, closable independent of the parent, appears in Window menu).

```swift
.alert("Delete “Q3 Report”?", isPresented: $showDeleteAlert) {
    Button("Delete", role: .destructive) { delete() }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("This cannot be undone.")
}
```

Do not use a sheet for something the user needs open while referencing the rest of the window (use a panel or split view instead), and do not use an alert for anything longer than a couple of sentences or with more than ~2-3 actions (use a sheet with real controls).

## Choosing the right feedback mechanism

Match urgency and blocking-ness to the mechanism:

- **Inline error/status text** next to the relevant control — for validation problems and recoverable states the user caused and can immediately fix. No interruption.
- **Alert** — for errors that stop the current task and require a decision, or confirmations of destructive, hard-to-undo actions.
- **Progress indicator** (`ProgressView`, determinate when duration is knowable, indeterminate otherwise) — for anything taking more than ~1 second; show it in place (inline spinner, progress bar in a status area) rather than blocking with an alert that says "please wait."
- **Local notification** (`UNUserNotificationCenter`) — for outcomes the user cares about but that complete *after* they've moved on to something else (a long export finished, a background sync failed) — never for something that happened while the app is frontmost and the user is watching it.

```swift
ProgressView(value: progress, total: 1.0) {
    Text("Exporting…")
}
```

Never stack two feedback mechanisms for the same event (e.g., an alert *and* a notification for the same completed export) — pick the one matching where the user's attention is likely to be, and prefer the least interruptive option that still gets noticed.

## Local notifications on the Mac

Request authorization once, contextually (right before the feature that needs it, not at launch), and only use `UNUserNotificationCenter` for events meaningful when the user is away from the app: a render finishing, a scheduled reminder, a download completing. Don't use notifications for routine in-app feedback the user is already looking at.

```swift
let center = UNUserNotificationCenter.current()
center.requestAuthorization(options: [.alert, .sound]) { granted, _ in }

let content = UNMutableNotificationContent()
content.title = "Export Complete"
content.body = "Q3 Report.pdf is ready."
let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
center.add(request)
```

Keep the title short and the body specific enough to act on, and make the notification's default tap action bring the user to the relevant window/document, not just to the front of the app.

## Going full screen and multitasking on Mac

Support full screen (`NSWindow` full-screen behavior / SwiftUI's automatic support) for any window whose content benefits from maximum screen space — video playback, writing, canvases — but never force full screen as the only mode. Preserve the same window/toolbar affordances in full screen that exist windowed; don't strip controls just because the chrome is hidden. On macOS 26 Tahoe, respect Stage Manager and standard window tiling/multi-window workflows: keep window sizing sensible and resizable, restore the previous size/position per window, and avoid fixed, tiny, non-resizable windows for primary content, since users routinely tile multiple app windows side by side.

## Full screen vs a maximized window

A user pressing the green button/full-screen control expects the content to expand to fill the display and hide distractions; this is different from simply maximizing a resizable window. Don't hijack full-screen entry to change navigation structure (e.g., hiding a sidebar the user relies on) unless the space is genuinely better used for content — and always give a clear, discoverable way back to windowed mode (moving the pointer to the top reveals the menu bar and the exit control by default; don't disable that).
