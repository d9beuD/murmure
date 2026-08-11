# Keyboard Shortcuts and Focus

Guidance for assigning key equivalents, avoiding conflicts with the system, and managing Tab/focus order on macOS 26 Tahoe.

## Standard modifier-key meanings on Mac

Don't invent new meanings for modifiers — reuse the conventions users already know:

- **⌘ (Command)** — the primary modifier for almost every app shortcut (⌘S Save, ⌘N New).
- **⇧ (Shift)** — added to a ⌘ shortcut to mean "reverse," "extend," or "alternate" (⌘⇧Z Redo, ⌘⇧N New Folder).
- **⌥ (Option)** — added for a secondary variant of a command (Option-click to reveal an alternate menu item, ⌘⌥Esc Force Quit).
- **⌃ (Control)** — rarely used in app shortcuts on Mac; mostly reserved for Terminal/Unix-style bindings and secondary-click emulation.

Never repurpose ⌘Q, ⌘W, ⌘Z, ⌘C/V/X, ⌘A, ⌘F, ⌘, (Preferences), or ⌘Space (Spotlight) for something other than their conventional meaning.

## Reusing standard system and menu shortcuts

Before assigning a new shortcut, check it isn't already claimed at the system or app level:

- System-wide: ⌘Space (Spotlight), ⌘Tab (App Switcher), ⌘⇧3/4 (screenshots), ⌘⌥Esc (Force Quit), ⌃⌘F (fullscreen).
- App menu (expected on almost every Mac app): ⌘Q Quit, ⌘, Preferences/Settings, ⌘H Hide, ⌘M Minimize, ⌘W Close Window.
- Standard Edit menu: ⌘Z/⌘⇧Z Undo/Redo, ⌘X/C/V, ⌘A Select All, ⌘F Find.
- Standard File menu: ⌘N New, ⌘O Open, ⌘S Save, ⌘P Print.

If your feature's natural shortcut is already taken, pick a nearby unused combination (add ⇧ or ⌥) rather than stealing the standard one.

## Assigning shortcuts with `.keyboardShortcut`

Attach shortcuts directly to the control that performs the action so the shortcut and its visible key equivalent never drift apart:

```swift
Button("Save") {
    document.save()
}
.keyboardShortcut("s", modifiers: .command)

Button("Duplicate") {
    document.duplicate()
}
.keyboardShortcut("d", modifiers: [.command, .shift])
```

Use the semantic shortcuts for default/cancel actions in dialogs instead of hardcoding a key:

```swift
Button("Delete", role: .destructive) { delete() }
    .keyboardShortcut(.defaultAction)   // Return

Button("Cancel", role: .cancel) { dismiss() }
    .keyboardShortcut(.cancelAction)    // Escape
```

## Key equivalents in menus

Any command exposed in a `Menu` or app `CommandGroup` should carry the same `.keyboardShortcut` used elsewhere for that action, so the menu's displayed key equivalent matches what actually fires:

```swift
CommandMenu("Format") {
    Button("Bold") { applyBold() }
        .keyboardShortcut("b", modifiers: .command)
    Button("Italic") { applyItalic() }
        .keyboardShortcut("i", modifiers: .command)
}
```

Only give a command a key equivalent if it's frequent or destructive enough to warrant one — not every menu item needs a shortcut.

## Tab and focus order

SwiftUI derives Tab order from view layout order automatically; verify it top-to-bottom, left-to-right before overriding anything:

```swift
VStack {
    TextField("Name", text: $name)
    TextField("Email", text: $email)
    Button("Submit") { submit() }
}
```

Only reorder focus explicitly when the visual layout and the logical order diverge (e.g., a sidebar that visually sits before the main form but should be reached after it).

## Programmatic focus with `@FocusState`

Use `@FocusState` to move focus in response to user actions (opening a sheet, submitting a form with a validation error) — not to hijack focus from something the user is actively using:

```swift
struct LoginForm: View {
    @FocusState private var focusedField: Field?
    enum Field { case username, password }

    var body: some View {
        VStack {
            TextField("Username", text: $username)
                .focused($focusedField, equals: .username)
            SecureField("Password", text: $password)
                .focused($focusedField, equals: .password)
        }
        .onAppear { focusedField = .username }
    }
}
```

Advance focus programmatically for multi-field entry (e.g., pressing Return in one field moves to the next) rather than forcing the user to reach for Tab or the mouse.

## Bridge to accessibility

Every custom control that accepts a shortcut or Tab focus must also work with Full Keyboard Access and VoiceOver — confirm the control is reachable via Tab and has a focus ring before moving on. Auditing VoiceOver labels, rotor content, and Switch Control scanning order in depth belongs to macos-best-practices, not this skill.
