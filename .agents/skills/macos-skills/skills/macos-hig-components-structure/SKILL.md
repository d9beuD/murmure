---
name: macos-hig-components-structure
description: >-
  Use when building or reviewing the structural/navigation shell of a macOS
  SwiftUI app — windows (Window, WindowGroup, defaultSize, windowStyle),
  panels and inspectors (NSPanel concepts, .inspector()), sheets
  (.sheet(isPresented:)), popovers (.popover), sidebars and split views
  (NavigationSplitView, List with sections), toolbars (.toolbar,
  ToolbarItem, SF Symbols), and menus / the menu bar / the Dock menu
  (CommandMenu, CommandGroup, keyboard shortcuts, contextual Menu) for
  macOS 26 Tahoe apps.
---

Helps you assemble the structural shell — windows, panels, sheets, popovers, sidebars, split views, toolbars, and menus — of a macOS 26 Tahoe SwiftUI app so it matches Apple's HIG.

## Use this skill when

- Declaring or configuring a `Window`/`WindowGroup`, sizing it, restoring its state, or styling its title bar.
- Adding a utility panel, an inspector, a sheet, or a popover, and unsure which container fits.
- Building or fixing a sidebar, a 2- or 3-column `NavigationSplitView`, or a resizable split layout.
- Adding, reordering, or fixing a window toolbar (`.toolbar { }`, `ToolbarItem`, SF Symbol icons, placement).
- Adding menu bar items, `CommandMenu`/`CommandGroup`, keyboard shortcuts, contextual menus, or a Dock menu.

## Do not use this skill when

- Choosing specific input controls (buttons, pickers, lists content) — use macos-hig-components-controls.
- Deciding modal patterns like sheet-vs-panel-vs-alert at the behavior level — use macos-hig-patterns (this skill covers how to build the chosen structure).
- Structuring App/Scene declarations and state — use macos-app-architecture.
- Choosing colors, typography, spacing, or SF Symbols weight/rendering — use macos-hig-foundations.
- Working with text fields, steppers, sliders, or other fine-grained input widgets — use macos-hig-inputs.
- General app-level conventions (undo, preferences window, About panel) not tied to one structural component — use macos-best-practices.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested UI structure works.

1. Identify which structural component is needed and open EXACTLY ONE reference file from the list below.
2. Prefer the platform-native container for the job: `NavigationSplitView` over a hand-rolled `HSplitView` for sidebar-based apps, `.sheet` for focused single-task modals, `.popover` for transient contextual info, a panel/`.inspector()` for persistent auxiliary controls tied to a selection.
3. Match every toolbar action to an equivalent menu command (and a keyboard shortcut where conventional) — do not add toolbar-only or menu-only actions for the same operation.
4. Wire keyboard shortcuts on `CommandGroup`/`CommandMenu` items using standard conventions (Cmd for primary actions, Cmd-Shift for variants); never override system-reserved shortcuts.
5. Keep window/sheet/popover sizing declarative (`.defaultSize`, `.frame(minWidth:...)`) rather than computing sizes imperatively.
6. Verify the structure builds and behaves: sidebar selection drives the detail column, sheets dismiss cleanly, toolbar items don't duplicate existing ones.
7. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not duplicate an existing window/sheet/toolbar; edit the existing declaration.
- Stop as soon as the structure renders and behaves correctly.

## Reference files

- `references/windows-panels-sheets-popovers.md` — open when working on `Window`/`WindowGroup` sizing/restoration/title bar, utility or inspector panels, `.sheet`, or `.popover`.
- `references/sidebars-split-views-toolbars.md` — open when building a sidebar, `NavigationSplitView`, resizable panes, or a `.toolbar` with `ToolbarItem`s.
- `references/menus-menu-bar-dock.md` — open when adding menu bar commands, `CommandMenu`/`CommandGroup`, keyboard shortcuts, contextual menus, or a Dock menu.
