# macOS Skills

A set of [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills) for **macOS app development with SwiftUI**, built from Apple's Human Interface Guidelines (HIG) and current SwiftUI/AppKit documentation. They give AI coding agents accurate, design-correct, version-correct guidance for building macOS apps — covering all five official HIG groups plus practical architecture and engineering best practices.

These skills are designed for **autonomous agents running small / local models** (limited context, low temperature, loop-prone). Each `SKILL.md` is a short, deterministic router: it points the agent to exactly one reference file per task, uses numbered imperative steps, and includes explicit anti-loop and stop criteria. Detailed code examples and design rules live in `references/*.md` and are loaded only when needed (progressive disclosure).

## Skills

| Skill | HIG group / scope |
|-------|-------|
| `macos-hig-foundations` | **Foundations** — layout, system/semantic color, Dark Mode, materials & vibrancy, typography & Dynamic Type, SF Symbols, app icon design, motion, sound, writing style |
| `macos-hig-patterns` | **Patterns** — document-based apps & file management, drag and drop, data entry, feedback & modality (sheet vs panel vs alert), notifications, full screen, settings window, search, undo/redo, onboarding |
| `macos-hig-components-structure` | **Components** (structure) — windows, panels, sheets, popovers, sidebars, split views, toolbars, menus & the menu bar, Dock menu |
| `macos-hig-components-controls` | **Components** (controls) — buttons, toggles, radio/segmented controls, sliders/steppers, pickers, lists & tables, text fields, progress indicators, color wells |
| `macos-hig-inputs` | **Inputs** — keyboard shortcuts & focus, pointer/trackpad gestures |
| `macos-app-architecture` | Practical engineering — `App`/`Scene`/`WindowGroup` structure, state management (`@Observable`, `@Environment`), MV/MVVM data flow, AppKit interop |
| `macos-best-practices` | **Technologies** (accessibility, privacy) + engineering — App Sandbox & entitlements, performance, testing, code signing & notarization, localization |

The first five skills map one-to-one onto the HIG's own top-level groups (**Foundations, Patterns, Components, Inputs** — Components is split into two skills because of its size); `macos-app-architecture` and `macos-best-practices` round out the set with the engineering practices a design-only pack would miss.

## Layout

```
skills/
└── macos-<name>/
    ├── SKILL.md            # short router: when to use, numbered steps, anti-loop rules
    └── references/         # detailed, code-rich docs loaded on demand
        └── *.md
```

## Installation

Copy the skills you want into your agent's skills directory. For example:

```bash
# Claude Code / agents using a .claude/skills directory
cp -R skills/macos-* /path/to/your/project/.claude/skills/

# or an .agents/skills directory
cp -R skills/macos-* /path/to/your/project/.agents/skills/
```

Each skill is self-contained — install only the ones you need. Pair this pack with [`swift-skills`](../swift-skills) for the underlying language.

## Versioning

Content targets **macOS 26 "Tahoe"** (currently at 26.6) and **Xcode 26**, the current stable SDK/IDE pair, with SwiftUI as the primary framework and AppKit interop covered where SwiftUI has no equivalent. **macOS 27 "Golden Gate"**, announced at WWDC26, is in beta at the time of writing and is only referenced where a feature is genuinely new to it. Update this pack's version references once macOS 27 ships.

## Contributing

Issues and pull requests are welcome — corrections, new references, or additional skills. Keep `SKILL.md` files short and router-style; put detail in `references/`.

## License

[MIT](LICENSE) © 2026 Vincent Bathelier.

Skill content is derived from Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) and [SwiftUI](https://developer.apple.com/documentation/swiftui)/[AppKit](https://developer.apple.com/documentation/appkit) documentation. "Apple," "macOS," "SwiftUI," and "AppKit" are trademarks of Apple Inc.; this is an independent, unofficial project.
