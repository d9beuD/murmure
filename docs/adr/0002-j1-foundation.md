# ADR 0002 — J1 Foundation

Status: partially implemented, awaiting Xcode validation

## Decision

The J1 foundation uses Swift Package Manager with two targets:

- `MurmureCore`: domain, states, service protocols, and `DictationCoordinator`;
- `Murmure`: SwiftUI app, `MenuBarExtra`, `Settings`, and macOS adapters.

This organization allows compilation with the Command Line Tools while maintaining a clear boundary for the future Xcode project. The bundle identifier, entitlements, and signing remain settings for the Xcode target that will be created once Xcode.app is available.

## Dependency injection

`AppEnvironment` injects `AudioRecording` and `TextDelivering` into `DictationCoordinator`. The SwiftUI model therefore does not know the details of AVFoundation or CoreGraphics.

## Metadata

`Configuration/Info.plist` contains the keys required for menu bar presence and the microphone request. It will serve as the basis for the Xcode target.

## Shortcut dependency

The package remains pinned to `KeyboardShortcuts` 1.10.0 so it can compile with the Command Line Tools. Recent versions use SwiftUI macro plugins that are unavailable without Xcode. Upgrading to the current version is planned when the Xcode target is created.

## Completed validation

```text
swift build                              ✅
swift build -Xswiftc -warnings-as-errors ✅
swift run Murmure                        ✅ graphical launch, stopped manually
```

Validation of permissions, the Dock icon, global events, and cross-application insertion remains manual on a machine with Xcode and a graphical macOS session.

## Post-J1 fix — deferred shortcut installation

`HotkeyService` now installs its handlers on the next pass through the main loop. Carbon registration performed too early during SwiftUI initialization can fail silently; deferring it ensures the macOS event dispatcher exists before restoring an already saved shortcut.

## Post-J2 fix — development bundle

`swift run Murmure` launches a raw Mach-O executable: `Configuration/Info.plist` is not linked to it, and LaunchServices does not consider it an application bundle. This notably makes activation of windows from a menu bar app unreliable. `Scripts/run-app.sh` now builds a `Murmure.app`, copies resources, applies `Info.plist`, performs ad hoc signing, and opens the bundle through LaunchServices.

## Consequence

J1 is functionally ready for J2 to begin, but milestone exit validation still depends on installing Xcode.app and generating the signed macOS target.
