---
name: macos-hig-components-controls
description: >-
  Use when adding or reviewing macOS SwiftUI content and input controls —
  buttons (.bordered, .borderedProminent, .plain, Menu pop-up/pull-down),
  checkboxes and toggles (Toggle with .checkbox/.switch style), radio buttons
  and segmented controls (Picker with .radioGroup/.segmented), sliders,
  steppers, combo-box-like pickers, List, Table with sortable columns,
  DisclosureGroup/OutlineGroup, TextField, TextEditor, SecureField, Label,
  ProgressView, and ColorPicker for macOS 26 Tahoe apps.
---

Build and review individual macOS 26 Tahoe SwiftUI controls — buttons, toggles, selection controls, lists/tables, text input, and status indicators — so each one matches AppKit-native HIG conventions instead of iOS defaults.

## Use this skill when

- Choosing a Button style, or deciding between a bordered button, a borderless (`.plain`) button, and a pop-up/pull-down `Menu`.
- Picking between a checkbox and a switch for a `Toggle`, or between radio buttons and a segmented control for a `Picker`.
- Wiring up a `Slider`, `Stepper`, editable combo-box-style picker, `List`, `Table` with sortable columns, or an outline/disclosure hierarchy.
- Adding or fixing `TextField`, `SecureField`, `TextEditor`, `Label`, `ProgressView`, or `ColorPicker`.
- Reviewing an existing control that looks or behaves like its iOS counterpart instead of its Mac counterpart.

## Do not use this skill when

- Structuring windows, sheets, sidebars, or toolbars — use macos-hig-components-structure.
- Deciding the underlying behavioral pattern (validation UX, modality, undo) — use macos-hig-patterns.
- Choosing color, typography, materials, or spacing tokens — use macos-hig-foundations.
- Wiring text field or picker values into `@Observable` model state, or app-wide data flow — use macos-app-architecture.
- Checking general Swift/SwiftUI code quality, performance, or testing conventions — use macos-best-practices.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested control works.

1. Identify which control is needed and open EXACTLY ONE reference file from the list below.
2. Prefer platform-idiomatic Mac control styles over iOS defaults: `.checkbox` toggle style (not `.switch`) for settings-panel booleans, `.radioGroup` or `.segmented` for short exclusive choices, `.bordered`/`.borderedProminent` buttons (not large iOS-style filled buttons), pull-down `Menu` for pop-up selection.
3. Bind the control directly to typed state (`@State`, `@Binding`, or a model property) — avoid stringly-typed selection or manual index bookkeeping.
4. Match the code snippet's structure in the reference file; adapt labels, bindings, and data types to the caller's model without inventing new modifiers.
5. If the control needs sorting, formatting, or validation beyond rendering (e.g., `Table` sort comparators, `FormatStyle`), apply the pattern shown in the reference file directly.
6. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not duplicate an existing control; edit the existing one in place.
- Stop as soon as the control renders and its binding works.

## Reference files

- `references/buttons-toggles-selection-controls.md` — open when adding/fixing Button styles, pop-up/pull-down Menu, Toggle (checkbox/switch), radio groups, segmented controls, sliders, or steppers.
- `references/lists-tables-text-fields.md` — open when adding/fixing List, Table with columns/sorting, DisclosureGroup/OutlineGroup, editable/combo-box pickers, TextField, SecureField, TextEditor, or Label.
- `references/progress-indicators-color-wells.md` — open when adding/fixing ProgressView (determinate/indeterminate) or ColorPicker.
