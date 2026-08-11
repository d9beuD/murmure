# Progress Indicators and Color Wells (macOS 26 Tahoe)

## Determinate progress for known-duration or measurable work

Use a determinate `ProgressView` whenever you can express progress as a fraction — file copies, downloads, multi-step imports, batch operations. Showing a filling bar (rather than a spinner) lets the user judge how much longer to wait, which HIG calls out as materially better for anything longer than a couple of seconds.

```swift
ProgressView(value: bytesCopied, total: totalBytes) {
    Text("Copying “\(fileName)”…")
} currentValueLabel: {
    Text(bytesCopied, format: .byteCount(style: .file))
}
```

## Indeterminate progress for unknown-duration work

Use an indeterminate `ProgressView` (no `value`) only when you genuinely cannot estimate completion — a network request of unknown size, a search still enumerating results. Don't default to indeterminate just because computing the fraction is inconvenient; a rough determinate estimate is almost always more useful to the user than a spinner.

```swift
ProgressView("Connecting…")
    .progressViewStyle(.circular)
```

## Linear vs. circular style

Use `.linear` for inline progress tied to a specific row, file, or region of content (a bar under a list row, in a toolbar accessory). Use `.circular` for a standalone, centered indicator representing the whole view or window's busy state — this matches the Mac convention of a spinning indicator for "the window is busy" and a bar for "this item is X% done."

```swift
ProgressView(value: progress)
    .progressViewStyle(.linear)

ProgressView()
    .progressViewStyle(.circular)
    .controlSize(.large)
```

## Reporting completion and errors, not just progress

A progress indicator should disappear or convert into a clear success/failure state when work finishes — don't leave a completed determinate bar sitting at 100% or a spinner running after an error. Pair long-running work with a cancel action when the operation is cancellable, per HIG guidance that indicators represent live, controllable state rather than decoration.

```swift
if isImporting {
    ProgressView(value: importProgress) {
        Text("Importing…")
    }
    Button("Cancel", role: .cancel) { cancelImport() }
        .buttonStyle(.bordered)
} else if let error = importError {
    Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
        .foregroundStyle(.red)
}
```

## Color wells for user-chosen colors

Use `ColorPicker` (backed by the system color well) any time the user picks a color for text, shapes, backgrounds, or annotations — never build a custom swatch grid or hex-entry field from scratch. The color well opens the standard macOS color panel, which already gives users sliders, swatches, image sampling, and recently-used colors for free.

```swift
ColorPicker("Highlight Color", selection: $highlightColor)
```

## Supporting or omitting opacity in a color well

Pass `supportsOpacity: false` when alpha is meaningless for the target (e.g., a solid UI accent color) so the color panel doesn't offer a control that would produce an invalid value; leave it enabled (the default) when the color is composited over other content, such as a highlight or fill.

```swift
ColorPicker("Accent Color", selection: $accentColor, supportsOpacity: false)

ColorPicker("Fill", selection: $fillColor)
```

## Compact color wells in dense UI

In toolbars, inspectors, or tightly packed rows, use `.labelsHidden()` on the `ColorPicker` and let its accompanying `Text` or `Label` carry the description instead, keeping the well itself at its compact default size rather than stretching it.

```swift
HStack {
    Text("Border Color")
    Spacer()
    ColorPicker("Border Color", selection: $borderColor)
        .labelsHidden()
}
```

## Skipping indicators for near-instant operations

Don't show a progress indicator at all for work that reliably completes in a few hundred milliseconds — a flashing spinner or bar that appears and disappears faster than the user can read it is noise. Reserve indicators for operations where the wait is actually perceptible, and prefer optimistic UI (show the result immediately, roll back on failure) for anything that fast.

## Binding a color well to model state, not raw components

Bind `ColorPicker`'s `selection` to a single `Color` (or `CGColor`) property on your model rather than separate red/green/blue/alpha bindings — this keeps the color well's built-in gamut and format handling intact and avoids re-deriving a `Color` by hand on every change.

```swift
@State private var accentColor: Color = .accentColor

ColorPicker("Accent Color", selection: $accentColor)
    .onChange(of: accentColor) { _, newColor in
        document.accentColor = newColor
    }
```

Cross-reference: when progress or a color change is the result of an action button, see `references/buttons-toggles-selection-controls.md`. When color selection lives inside a larger settings list or table row, see `references/lists-tables-text-fields.md`.
