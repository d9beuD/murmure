---
name: macos-best-practices
description: >-
  Use when implementing accessibility (VoiceOver, .accessibilityLabel,
  .accessibilityHint, .accessibilityValue, Dynamic Type, reduce motion/
  transparency), App Sandbox entitlements, security-scoped bookmarks,
  privacy usage-description strings, performance tuning with Instruments,
  XCTest/Swift Testing UI tests, code signing, notarization with
  notarytool, or localization for macOS apps.
---

Helps implement the engineering-level HIG Technologies requirements — accessibility, privacy, performance, testing, distribution, and localization — for macOS 26 Tahoe apps built with Xcode 26.

## Use this skill when

- Adding `.accessibilityLabel`/`.accessibilityHint`/`.accessibilityValue` or grouping elements with `.accessibilityElement(children:)` for VoiceOver.
- Supporting Dynamic Type, `.accessibilityReduceMotion`, or `.accessibilityReduceTransparency`.
- Enabling App Sandbox, choosing entitlements, or wiring up security-scoped bookmarks for persisted file access.
- Adding an `Info.plist` usage-description key (camera, microphone, location, etc.) before requesting a permission.
- Diagnosing main-thread hangs, slow `List`/`Table` rendering, or profiling with Instruments.
- Writing XCTest/Swift Testing unit or UI (`XCUIApplication`) tests for a macOS app.
- Code signing, notarizing (`xcrun notarytool`), stapling, or deciding Developer ID vs. Mac App Store distribution.
- Adopting `String(localized:)`, `.xcstrings` catalogs, or plural rules.

## Do not use this skill when

- Choosing colors/typography or basic input-focus behavior — use macos-hig-foundations or macos-hig-inputs (come back here for the accessibility *implementation* details).
- Structuring the app/state itself — use macos-app-architecture.
- Deciding which pattern (settings window, onboarding flow, etc.) to use — use macos-hig-patterns.
- Choosing or laying out a specific component/control — use macos-hig-components-structure or macos-hig-components-controls.

## Instructions

Follow these steps in order. Do the minimum needed; stop when the requested requirement is satisfied.

1. Identify the concern (accessibility, privacy/sandbox, performance, testing, or distribution/localization) and open EXACTLY ONE reference file from the list below.
2. Request the narrowest entitlement/permission that satisfies the feature; add accessibility labels alongside the control that needs them, not as an afterthought pass.
3. Copy the matching snippet (entitlement XML, usage-description key, Instruments workflow, notarytool command, or test scaffold) and adapt names/identifiers to the current code — don't invent new entitlement or plist key names.
4. If the task is a permission or entitlement request, pair it with the required `Info.plist`/`.entitlements` key in the same change, not a follow-up.
5. Verify with the lightest tool that proves the requirement: Accessibility Inspector for a11y, `codesign --verify`/`spctl` for signing, a quick Instruments trace for perf, or running the test target for tests.
6. Stop here.

Anti-loop rules:
- ONE reference file per task.
- Do not request broad entitlements "just in case"; request only what the current feature needs.
- Do not add usage-description strings for permissions the feature doesn't actually trigger.
- Stop as soon as the requirement (accessibility label, entitlement, signed/notarized build, passing test) is satisfied.

## Reference files

- `references/accessibility-privacy-sandbox.md` — open when adding VoiceOver support, Dynamic Type/reduce-motion handling, App Sandbox entitlements, security-scoped bookmarks, or Info.plist privacy usage descriptions.
- `references/performance-testing.md` — open when profiling with Instruments, fixing main-thread blocking or slow `List`/`Table` rendering, or writing XCTest/Swift Testing unit and UI tests.
- `references/distribution-signing-notarization.md` — open when code signing, notarizing with `notarytool`, stapling, choosing Developer ID vs. Mac App Store, or setting up localization/`.xcstrings` catalogs.
