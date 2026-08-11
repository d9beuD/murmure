# AGENTS.md

## Scope
- This repo is a macOS app development skill pack (design + engineering), not an application.
- Keep changes aligned with Apple's Human Interface Guidelines (developer.apple.com/design/human-interface-guidelines) and current SwiftUI/AppKit APIs, and with the existing skill router style.

## Repo layout
- `skills/<skill-name>/SKILL.md` is the router file for each skill.
- `skills/<skill-name>/references/*.md` holds the detailed, on-demand docs.
- Keep `SKILL.md` short and deterministic; put examples and detail in `references/`.
- The five `macos-hig-*` skills map directly to the five official HIG groups (Foundations, Patterns, Components — split into structure/controls, Inputs). `macos-app-architecture` and `macos-best-practices` are practical engineering additions (state management, AppKit interop, accessibility, sandboxing, distribution).

## What to preserve
- Target macOS 26 "Tahoe" / Xcode 26 as the stable baseline. Note macOS 27 "Golden Gate" (WWDC26, in beta) only where a feature is genuinely new to it.
- Keep router instructions numbered, imperative, and anti-loop focused.
- Do not add extra abstractions, heuristics, or speculative guidance.
- Prefer exact SwiftUI/AppKit API names and verified examples over generic advice; never invent modifiers or entitlement keys.

## Editing rules
- When updating a skill, fix the router and the matching reference together if needed.
- Do not open or rewrite every reference file for a small change; touch only the relevant ones.
- When a new macOS/Xcode version ships, update version references in README.md and each SKILL.md consistently.

## Verification
- Check that any new or edited skill still points to exactly one relevant reference per task path.
- Keep the README and skill descriptions consistent with the actual file layout and supported macOS version.
