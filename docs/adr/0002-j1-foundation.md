# ADR 0002 — J1 Foundation

Status: functionally implemented, awaiting interactive Xcode validation

## Decision

The J1 foundation is implemented with Swift Package Manager and two production targets:

- `MurmureCore`: domain, states, service protocols, and `DictationCoordinator`;
- `Murmure`: SwiftUI app, `MenuBarExtra`, `Settings`, and macOS adapters.

This organization allows compilation and testing with the repository CI commands while maintaining clear separation between app UI/adapters and core domain logic. Runtime validation still depends on launching an Xcode-capable, signed macOS application bundle.

## Dependency injection

`AppEnvironment` injects services into `DictationCoordinator`. The SwiftUI model therefore does not know the details of AVFoundation, networking, persistence, keychain storage, or text delivery.

## Metadata

`Configuration/Info.plist` contains the keys required for menu bar presence, including `LSUIElement`, and the microphone request. `Sources/Murmure/MurmureApp.swift` provides the `MenuBarExtra` and `Settings` scenes.

## Shortcut dependency

The package remains pinned to `KeyboardShortcuts` 1.10.0. Shortcut handler installation is deferred to the next main-loop pass so saved shortcuts restore after the macOS event dispatcher exists.

## Completed validation

```text
swift build                              ✅
swift build -Xswiftc -warnings-as-errors ✅
swift test -Xswiftc -warnings-as-errors  ✅
```

CI build/test coverage and source evidence cover the SPM target split, dependency injection, `MenuBarExtra`/`Settings`, `LSUIElement`, and warnings-as-errors commands.

Remaining manual validation: launch the Xcode-signed `.app` bundle in a graphical macOS session; confirm menu-bar-only presence/no Dock icon, permissions prompts, global shortcut events, and cross-application insertion.

## Post-J1 fix — deferred shortcut installation

`HotkeyService` now installs its handlers on the next pass through the main loop. Carbon registration performed too early during SwiftUI initialization can fail silently; deferring it ensures the macOS event dispatcher exists before restoring an already saved shortcut.

## Post-J2 fix — development bundle

`swift run Murmure` launches a raw Mach-O executable: `Configuration/Info.plist` is not linked to it, and LaunchServices does not consider it an application bundle. This notably makes activation of windows from a menu bar app unreliable. `Scripts/run-app.sh` now builds a `Murmure.app`, copies resources, applies `Info.plist`, performs ad hoc signing, and opens the bundle through LaunchServices.

## Consequence

J1 is functionally implemented and ready for later milestones. Final exit validation still depends on an interactive run of the Xcode-signed macOS bundle.
