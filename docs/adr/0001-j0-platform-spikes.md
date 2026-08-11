# ADR 0001 — J0 Spike Results

Status: partially implemented, awaiting interactive macOS validation
Date: August 5, 2026

## Context

J0 must validate the system capabilities that could challenge Murmure's architecture: a menu-bar-only app, global key-down/key-up events, WAV capture, clipboard access, and automatic pasting.

## Spike implementation

The repository initially contained an executable Swift Package named `MurmureSpike`, since refactored into the `Murmure` target, with:

- SwiftUI `MenuBarExtra` and `Settings` scenes;
- two trigger modes;
- the MIT-licensed `KeyboardShortcuts` dependency;
- 16 kHz, 16-bit, mono PCM WAV capture through `AVAudioRecorder`;
- a clipboard test;
- an insertion test using a Command-V event;
- explicit deletion of the latest capture.

Static repository evidence covers menu-bar-only behavior, WAV capture, clipboard access, and insertion code. Runtime validation is still pending for global key-down/key-up events, cross-application paste behavior, and the App Sandbox decision.

The spike uses `AVAudioRecorder` to quickly isolate validation of the format and permissions. The final version may replace this implementation with `AVAudioEngine` without changing the coordinator.

The J0 manifest temporarily pins `KeyboardShortcuts` 1.10.0: versions 2.x/3.x use SwiftUI macros whose plugins are not provided by the Command Line Tools alone. J1 will return to the current version validated with Xcode and update `Package.resolved`.

## Manual validation prerequisites

The current environment provides Swift 6.3.3 and the macOS 26 SDK, but not Xcode.app. The Swift Package can therefore be compiled with `swift build`; interactive validation must be performed with a macOS app launched from Xcode or from an `.app` bundle.

Remaining manual checks on macOS 26:

1. Global shortcut receives `keyDown` and `keyUp` events when Murmure is not focused.
2. Cross-application paste works in Notes, TextEdit, Terminal, and a code editor.
3. Missing Accessibility permission does not prevent clipboard mode from working.
4. App Sandbox is tested with both delivery modes.

## Provisional decision

The App Sandbox decision remains open until sandboxed delivery is validated. Direct distribution, Hardened Runtime, and a clipboard fallback remain the backup strategy if global events or cross-application insertion are incompatible with the sandbox.

## Commands

```shell
swift build
swift run Murmure
```

`swift run` requires a graphical macOS context to display the menu bar and is not suitable for a CI runner without a user session.
