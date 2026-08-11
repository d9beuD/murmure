---
name: macos-hig-patterns
description: >-
  Use when designing or reviewing interaction patterns for a macOS 26 Tahoe
  SwiftUI/AppKit app — document-based apps and file management (open/save
  panels, autosave, versions, DocumentGroup/FileDocument), drag and drop
  (.draggable/.dropDestination), entering data and form validation, choosing
  between an alert vs inline error vs notification vs progress indicator,
  going full screen and window/Stage Manager multitasking, fast launching and
  state restoration, skeleton/loading states, modality (sheet vs panel vs
  alert vs full window), local notifications, lightweight onboarding, audio
  and video playback, printing, search field placement and live filtering,
  the Settings window pattern, and undo/redo with UndoManager on macOS.
---

Guides an agent building or reviewing a macOS 26 Tahoe app through the HIG "Patterns" group — the interaction and workflow decisions (not visual style, not specific widgets) that make an app behave the way users expect.

## Use this skill when

- Building a document-based app: open/save panels, autosave, versions, `DocumentGroup`/`FileDocument`.
- Implementing drag and drop between views, windows, or apps.
- Designing a form: field order, inline validation, defaults, AutoFill.
- Deciding how to surface an error, warning, success, or long-running task (alert vs inline vs notification vs progress).
- Deciding whether a new UI surface should be a sheet, a panel, an alert, or a separate window.
- Adding full-screen support, or supporting Stage Manager / multi-window workflows.
- Speeding up launch or restoring the user's previous window/document state.
- Showing a loading/skeleton state for slow content.
- Sending a local notification via `UNUserNotificationCenter`.
- Writing a first-run/onboarding experience.
- Playing audio/video with `AVKit`, adding printing, or building a search field.
- Building the app's `Settings` scene, or wiring up `UndoManager`/`@Environment(\.undoManager)`.

## Do not use this skill when

- Choosing visual style (color, typography, materials) — use macos-hig-foundations.
- Picking which specific window/menu/control widget to use — use macos-hig-components-structure or macos-hig-components-controls.
- Deciding keyboard, pointer, or Touch Bar/trackpad input handling in detail — use macos-hig-inputs.
- Structuring app targets, data layers, or dependency injection — use macos-app-architecture.
- General Swift/SwiftUI code style not tied to a HIG pattern — use macos-best-practices.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested behavior works.

1. Identify the interaction pattern needed and open EXACTLY ONE reference file from the list below.
2. Match the severity/urgency of feedback to the right UI: don't use a blocking alert for a recoverable warning, don't silently fail where the user needs to act, don't send a notification for something the user is actively looking at.
3. Prefer sheets for document- or task-scoped modal work; prefer non-activating panels for persistent tool UI (inspectors, palettes); reserve full separate windows for independent, non-modal tasks; reserve alerts for decisions or errors the user must acknowledge before continuing.
4. When adding a destructive or state-changing action, wire it through `UndoManager` rather than adding a separate confirmation dialog, unless the action is irreversible (e.g. deleting from disk, sending) or destroys unrelated data.
5. Implement the minimal SwiftUI/AppKit surface from the reference file's snippet, adjusting names to the app's existing types.
6. Verify the pattern reads correctly at the smallest and largest expected window sizes and doesn't trap the user (every sheet/panel has a clear dismiss path).
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not introduce a new modal surface when an existing sheet/panel already serves the purpose.
- Do not add a second feedback mechanism (e.g. alert AND notification) for the same event.
- Stop as soon as the interaction pattern behaves correctly — do not keep refactoring working modal/undo/form logic.

## Reference files

- `references/documents-drag-drop-data-entry.md` — open when building a document-based app, file open/save/autosave/versions, drag and drop, or a data-entry form.
- `references/modality-feedback-notifications.md` — open when choosing between sheet/panel/alert/window, picking an error/feedback mechanism, going full screen, or sending local notifications.
- `references/settings-search-undo-onboarding.md` — open when building the Settings window, a search field, undo/redo, onboarding, launch/loading behavior, audio/video playback, or printing.
