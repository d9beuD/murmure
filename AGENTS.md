# Murmure — Agent Instructions

macOS 26 menu-bar dictation app. Swift 6.2 SPM package. No Xcode project.

## Commands

| Task | Command |
|------|---------|
| Build | `swift build` |
| Build (CI) | `swift build -Xswiftc -warnings-as-errors` |
| Test | `swift test -Xswiftc -warnings-as-errors` |
| Run app | `./Scripts/run-app.sh` |
| Release DMG | `./Scripts/release.sh` (needs env vars) |

**Do NOT use `swift run Murmure`.** It produces a raw executable without `.app` bundle metadata. The app needs `Info.plist`, code signing, and resource bundles — only `./Scripts/run-app.sh` provides that.

Tests require a full Xcode installation (Command Line Tools alone do not include XCTest).

## Package structure

- `Sources/Murmure/` — executable target (SwiftUI app, services, features)
- `Sources/MurmureCore/` — library target (domain types, protocols, coordinator, persistence, logging)
- `Sources/MurmureSpike/` — empty spike target (keep it, do not delete)
- `Tests/MurmureCoreTests/` — unit tests for MurmureCore
- `Tests/MurmureSpikeTests/` — empty spike tests
- `Configuration/Info.plist` — applied by run/release scripts (not embedded by SPM)
- `Scripts/` — `run-app.sh`, `build-dmg.sh`, `release.sh`

## Architecture

- `MenuBarExtra` only, no Dock icon (`LSUIElement = true` in `Configuration/Info.plist`)
- Entry point: `Sources/Murmure/MurmureApp.swift` (`@main`)
- `AppModel` (@MainActor, @Observable) → `DictationCoordinator` → injected services
- All services injected via `AppEnvironment` (protocols in `MurmureCore/Domain.swift`)
- State machine: `DictationState` enum (idle → requestingPermission → recording → transcribing → error)
- Settings persisted in `UserDefaults` with versioned schema (`AppPreferences.schemaVersion`)
- API keys stored in macOS Keychain only, never in UserDefaults or logs
- Networking: ephemeral `URLSession`, no persistent cache/cookies, cross-origin redirects rejected
- Audio: 16 kHz mono PCM WAV, min 250 ms, max 10 min watchdog
- Logs: in-memory only, no secrets/transcripts/audio in log output

## Dependencies

- `KeyboardShortcuts` (sindresorhus) — exact 1.10.0, tracked in `Package.resolved`
- No other third-party dependencies. Networking is native `URLSession`.

## Conventions

- Swift 6 strict concurrency. All domain types are `Sendable`.
- Warnings treated as errors in CI (`-Xswiftc -warnings-as-errors`).
- Protocol-based testability: `AudioRecording`, `SpeechTranscribing`, `TextCleaning`, `TextDelivering`.
- `@MainActor` on UI-facing types and protocols that touch AppKit.
- No file or audio artifacts committed (`.gitignore` covers `.build/`, `.swiftpm/`, `DerivedData/`).
- CI audits for tracked audio/secrets: `! git ls-files | grep -E '\.(wav|p12|mobileprovision)$'`

## Release

- `./Scripts/release.sh` needs: `MURMURE_VERSION`, `DEVELOPER_ID_CERTIFICATE_BASE64`, `DEVELOPER_ID_CERTIFICATE_PASSWORD`, `BUILD_KEYCHAIN_PASSWORD`, `APP_STORE_CONNECT_KEY_BASE64`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`.
- GitHub Actions `release.yml` (manual dispatch) handles signing, notarization, DMG, and GitHub release creation.
- Version format: `x.y.z` (no `v` prefix in env var, tag gets `v` prefix).
