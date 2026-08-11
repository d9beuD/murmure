# Buttons, Toggles, and Selection Controls (macOS 26 Tahoe)

## Bordered buttons for standard actions

Use `.bordered` for ordinary actions and `.borderedProminent` for the single default/primary action in a view (the one triggered by Return). Do not make every button prominent — HIG treats prominence as scarce emphasis, not decoration. Avoid iOS-style large filled full-width buttons; Mac buttons size to their content plus standard padding.

```swift
HStack {
    Button("Cancel") { dismiss() }
        .buttonStyle(.bordered)
    Button("Save") { save() }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
}
```

## Plain buttons for toolbars and inline actions

Use `.plain` (borderless) for toolbar icons, inline row actions, and anywhere a bordered box would add visual noise next to text or list rows. Pair with `Label` so the button still has an accessible text alternative even when only the icon is visible.

```swift
Button {
    toggleFavorite()
} label: {
    Label("Favorite", systemImage: isFavorite ? "star.fill" : "star")
}
.buttonStyle(.plain)
```

## Pop-up and pull-down buttons via Menu

A `Menu` whose label reflects the current selection reads as a pop-up button; a `Menu` with a fixed label (like an icon or "Actions") reads as a pull-down button. Use a pop-up button when the control shows the current value from a small closed set (favor `Picker` with `.menu` style instead when the value is bound to model state — see the lists/text-fields reference). Use a pull-down for a menu of commands.

```swift
Menu("Actions") {
    Button("Duplicate") { duplicate() }
    Button("Rename…") { rename() }
    Divider()
    Button("Delete", role: .destructive) { delete() }
}
.menuStyle(.button)
```

## Checkbox toggles for independent settings

Use `Toggle` with `.checkbox` style for standalone boolean settings in forms, inspectors, and preference panes — this is the native Mac idiom, not `.switch`. Checkboxes read as "this setting is on/off"; switches read as iOS and feel out of place in dense settings UI.

```swift
Toggle("Show hidden files", isOn: $showsHiddenFiles)
    .toggleStyle(.checkbox)
```

## Switch toggles for immediate, standalone on/off actions

Reserve `.switch` style for a single prominent on/off control that takes effect immediately (e.g., a top-level feature flag in a full-window settings screen), closer to how switches read in System Settings panes. When in doubt for a form row, default to `.checkbox`.

```swift
Toggle("Enable Live Text", isOn: $liveTextEnabled)
    .toggleStyle(.switch)
```

## Radio groups for a small set of exclusive options

Use `Picker` with `.radioGroup` style when every option should be visible at once and the set is short (roughly 2–5 items) and the choice matters enough to warrant permanent visibility, per HIG "Buttons" and "Toggles" guidance on showing all options for infrequent, consequential choices.

```swift
Picker("Alignment", selection: $alignment) {
    Text("Leading").tag(HorizontalAlignment.leading)
    Text("Center").tag(HorizontalAlignment.center)
    Text("Trailing").tag(HorizontalAlignment.trailing)
}
.pickerStyle(.radioGroup)
```

## Segmented controls for view-mode or filter switches

Use `Picker` with `.segmented` style for short, mutually exclusive choices that change what's currently displayed (view mode, tab-like filters) rather than a persistent document setting — segmented controls read as transient state, radio groups read as saved preferences.

```swift
Picker("View", selection: $viewMode) {
    Text("List").tag(ViewMode.list)
    Text("Grid").tag(ViewMode.grid)
}
.pickerStyle(.segmented)
.labelsHidden()
```

## Sliders for continuous or large ranged values

Use `Slider` when the exact numeric value matters less than relative position, and the range is large or continuous (opacity, volume, zoom). Always give the slider a label (visible or accessibility) and show the live value nearby if precision matters to the user.

```swift
Slider(value: $opacity, in: 0...1) {
    Text("Opacity")
} minimumValueLabel: {
    Text("0%")
} maximumValueLabel: {
    Text("100%")
}
```

## Steppers for small, precise, discrete values

Use `Stepper` for small integer or discrete ranges where the user cares about the exact number (font size, quantity, row count), typically paired with a `TextField` or `Text` showing the current value so the stepper isn't the only source of truth.

```swift
Stepper(value: $fontSize, in: 8...72) {
    Text("Font Size: \(fontSize, format: .number)")
}
```

## Choosing between these controls

- One-off command → `Button` (`.bordered`/`.borderedProminent`/`.plain`).
- Menu of commands or a value picked from a compact closed set → `Menu` (pull-down/pop-up).
- Independent boolean setting in a form → `Toggle(.checkbox)`.
- Single prominent immediate on/off → `Toggle(.switch)`.
- 2–5 persistent, always-visible exclusive options → `Picker(.radioGroup)`.
- 2–5 transient view/filter states → `Picker(.segmented)`.
- Continuous/large range → `Slider`.
- Small precise discrete range → `Stepper`.

Cross-reference: for a `Picker` bound to a large or open-ended list of options (menu-style picker, editable combo box), see `references/lists-tables-text-fields.md` in this skill.
