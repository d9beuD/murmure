---
name: macos-hig-inputs
description: >-
  Use when implementing or reviewing keyboard shortcuts, .keyboardShortcut,
  Tab/focus order, @FocusState, key equivalents in menus, mouse/trackpad
  interactions (.onHover, secondary click, scroll, swipe, pinch), or Full
  Keyboard Access support for macOS apps.
---

Guide keyboard, mouse, trackpad, and focus behavior for macOS 26 Tahoe apps so every interaction is discoverable, conflict-free, and reachable without a mouse.

## Use this skill when

- Assigning a keyboard shortcut to a command, button, or menu item.
- Deciding Tab order or managing focus with `@FocusState`.
- Adding hover feedback, secondary-click menus, or trackpad gestures (swipe, pinch).
- Checking whether a shortcut collides with a standard system or app-menu shortcut.
- Making a pointer-only interaction (drag, hover, right-click) reachable from the keyboard.

## Do not use this skill when

- Deep accessibility implementation (VoiceOver labels, Dynamic Type auditing) beyond basic input focus — use macos-best-practices.
- Choosing which control to attach a shortcut/gesture to structurally — use macos-hig-components-structure or macos-hig-components-controls.
- General window, menu bar, or toolbar layout decisions — use macos-hig-patterns or macos-hig-foundations.
- Non-macOS platforms (iOS/iPadOS touch-only input, watchOS) — this skill assumes a physical keyboard and pointing device.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested input behavior works.

1. Identify the input concern and open EXACTLY ONE reference file from the list below.
2. Reuse standard Mac keyboard-shortcut conventions (⌘ for primary commands, ⇧ adds "reverse"/extend, ⌥ adds a variant, ⌃ is rarely used for shortcuts) instead of inventing new modifier meanings.
3. Before assigning a shortcut, check it against the standard system/menu shortcuts list in the reference file; pick an unused combination if there's a conflict.
4. Ensure every mouse-only interaction (hover reveal, drag, secondary click, trackpad gesture) has a keyboard-reachable equivalent, even if slower.
5. Wire focus explicitly with `@FocusState` only when the default Tab order or default first responder is wrong; otherwise rely on SwiftUI's automatic focus order.
6. Verify the result: the action fires from a key equivalent shown in its menu (if it has one) AND from a click/gesture, and Tab reaches it in a logical order.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not assign a keyboard shortcut that conflicts with a standard system/menu shortcut.
- Stop as soon as the input behavior works via both pointer and keyboard.

## Reference files

- `references/keyboard-shortcuts-focus.md` — open when assigning `.keyboardShortcut()`, resolving a shortcut conflict, setting Tab/focus order, or moving focus programmatically with `@FocusState`.
- `references/pointer-trackpad-gestures.md` — open when adding hover states, secondary-click menus, scroll behavior, or trackpad gestures like swipe-to-navigate and pinch-to-zoom.
