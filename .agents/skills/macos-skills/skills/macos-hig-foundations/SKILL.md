---
name: macos-hig-foundations
description: >-
  Use when making visual/design decisions for a macOS app: window layout and
  resizing, safe areas and alignment/spacing, system and semantic colors
  (.primary/.secondary/accentColor), Dark Mode support, materials and
  vibrancy (sidebar/toolbar/window backgrounds, .regularMaterial), typography
  and Dynamic Type on Mac, SF Symbols weight/scale/rendering-mode/variants,
  macOS app icon design (Icon Composer, rounded-rect grid, layered icons),
  motion/animation restraint, sound feedback, and macOS UI writing style.
---

Apply Apple's Human Interface Guidelines "Foundations" group to give a macOS 26 Tahoe SwiftUI app correct layout, color, materials, typography, iconography, motion, sound, and writing conventions.

## Use this skill when

- Sizing, resizing, or laying out a window, sidebar, or content area on macOS.
- Choosing a color: system color, semantic color, accent color, or tint, and making it Dark Mode-safe.
- Deciding which `Material` (vibrancy/translucency) to use behind a sidebar, toolbar, or window.
- Setting fonts, text styles, Dynamic Type, or monospaced/rounded font variants.
- Picking an SF Symbol, its weight/scale, rendering mode, or a fill/slash/circle variant.
- Designing or reviewing a macOS app icon (rounded-rect grid, layered/Icon Composer icon).
- Deciding whether/how much to animate a UI change, or whether to play a sound.
- Wording a button, menu item, label, or alert per macOS capitalization/terminology conventions.
- Checking a Foundations-level privacy-by-design concern (data minimization, transparency).

## Do not use this skill when

- Choosing which window/menu/control structure to use — use macos-hig-components-structure or macos-hig-components-controls.
- Deciding app architecture (@State, App/Scene structure) — use macos-app-architecture.
- Choosing input handling (keyboard, mouse, trackpad, gestures) — use macos-hig-inputs.
- Applying a cross-cutting interaction pattern (undo, drag and drop, search) — use macos-hig-patterns.
- Following general Swift/SwiftUI coding conventions unrelated to visual design — use macos-best-practices.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested design decision is made.

1. Identify the design question and open EXACTLY ONE reference file from the list below.
2. Prefer a system-provided semantic value (semantic color, named `Material`, system text style, SF Symbol) over any hardcoded value, so Dark Mode, accent-color changes, and accessibility settings apply automatically.
3. For layout: size to content with sensible min/max, respect safe areas, and use consistent spacing (8pt-based) rather than one-off magic numbers.
4. For icons: keep the icon inside the macOS rounded-rectangle grid and build it in Icon Composer as layers, not as a flat exported PNG.
5. For motion and sound: default to none; add only a short, purposeful animation or system sound when it clarifies a state change, and never block interaction on it.
6. For writing: match the capitalization and terminology rules in the reference file exactly rather than guessing.
7. Apply the decision directly in the SwiftUI code under review or being written. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not hardcode colors, fonts, or icon assets when a system-provided semantic equivalent exists.
- Do not re-derive HIG rules from memory once a reference file gives the concrete answer — use what it says.
- Stop as soon as the visual/design decision is applied; do not keep tuning values with no new requirement.

## Reference files

- `references/layout-color-materials.md` — open for window/layout sizing, safe areas, spacing, system/semantic colors, accent color, Dark Mode, or materials/vibrancy questions.
- `references/typography-icons-sf-symbols.md` — open for font/text-style/Dynamic Type questions, SF Symbol weight/scale/rendering-mode/variant choices, or macOS app icon design.
- `references/motion-sound-writing.md` — open for animation/motion restraint, system sound usage, or UI copy/capitalization/terminology questions.
