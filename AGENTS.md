# Murmure — Agent Instructions

Murmure is a privacy-conscious macOS 26 menu-bar dictation app. It records speech, sends it to an OpenAI-compatible speech-to-text (STT) endpoint, optionally cleans the transcript through an OpenAI-compatible text endpoint (TTT), then copies or inserts the result into the active app.

The repository is a Swift Package Manager project with no Xcode project. `Package.swift` uses Swift tools 6.2; development and CI currently use Xcode 26, Swift 6.3, and the macOS 26 SDK.

## Product behavior

- The app is a `MenuBarExtra` with no Dock icon (`LSUIElement = true`). Settings, logs, and onboarding are separate SwiftUI windows whose default launch behavior is suppressed.
- Dictation supports push-to-talk and toggle shortcuts, with a 150 ms debounce. Escape cancels an active permission request, recording, or transcription.
- The state machine is `idle -> requestingPermission -> recording -> transcribing -> idle/error`. Cleanup runs while the state remains `transcribing`.
- Recordings are 16 kHz mono PCM WAV files. Dictations shorter than 250 ms are rejected and a 10-minute watchdog stops long recordings.
- While recording, a non-activating floating indicator follows the caret and reacts to the microphone level. Its label changes from Listening to Transcribing and, when enabled, Improving text.
- Output is either clipboard-only or automatic insertion. Secure fields and missing Accessibility permission always fall back to copying.
- The UI is localized in English and French (`en`, `fr-FR`). Users can follow the system language or override it live without relaunching the app.
- First launch opens a five-step onboarding flow. The app also exposes STT connection testing, permission controls, launch at login, sound feedback, in-memory logs, and Sparkle updates.

## Commands

| Task | Command |
|------|---------|
| Build | `swift build` |
| Build as CI | `swift build -Xswiftc -warnings-as-errors` |
| Test as CI | `swift test -Xswiftc -warnings-as-errors` |
| Test with coverage gates | `./Scripts/check-coverage.sh` |
| Build, sign, verify, and launch the development app | `./Scripts/run-app.sh` |
| Assemble without launching | `MURMURE_SKIP_OPEN=1 ./Scripts/run-app.sh` |
| Verify an assembled app | `./Scripts/verify-app-bundle.sh "$(swift build --show-bin-path)/Murmure.app"` |
| Build, sign, notarize, and report the digest of a release DMG | `./Scripts/release.sh` (requires release environment variables) |

**Never use `swift run Murmure` to validate application behavior.** It launches a raw executable without the app's `Info.plist`, entitlements, embedded frameworks, compiled localization catalogs, stable code signature, or LaunchServices behavior. Use `./Scripts/run-app.sh`.

A full Xcode installation is required for tests (`XCTest`) and app assembly (`xcstringstool`). Command Line Tools alone are insufficient. If necessary, select Xcode with `xcode-select` or `DEVELOPER_DIR`.

Before rebuilding the development `.app`, quit a running Murmure instance. `run-app.sh` deliberately refuses to replace a live bundle so macOS can retain its permissions consistently.

## Package structure

- `Sources/MurmureCore/` — reusable domain types, the dictation coordinator, injected ports, and log-safety helpers. It must not depend on AppKit or concrete infrastructure.
- `Sources/Murmure/` — executable target containing SwiftUI/AppKit presentation, application models, feature controllers, and live adapters.
  - `App/` — `MurmureApp`, `CompositionRoot`, `AppModel`, dependencies, presentation mapping, and localization.
  - `Features/` — menu bar, settings, onboarding, live logs, and the listening indicator.
  - `Infrastructure/` — Accessibility, audio, cleanup, delivery, hotkeys, networking, persistence, system services, and transcription adapters.
  - `Resources/` — `Localizable.xcstrings` and `InfoPlist.xcstrings`.
- `Tests/MurmureCoreTests/` — domain and coordinator tests.
- `Tests/MurmureTests/` — application, localization, feature, and infrastructure tests.
- `Configuration/Info.plist` — bundle identity, menu-bar mode, microphone usage text, Sparkle configuration, and supported localizations.
- `Configuration/Murmure.entitlements` — signing entitlements; the app is currently distributed outside the App Sandbox.
- `Scripts/` — development app assembly, bundle verification, coverage, DMG construction, and release/notarization.
- `docs/adr/` — milestone decisions and architectural rationale. Treat older “awaiting validation” notes as historical when newer code/tests/scripts supersede them.

## Architecture and runtime flow

- Entry point: `Sources/Murmure/App/MurmureApp.swift` (`@main`).
- `CompositionRoot.makeAppModel()` is the only place that builds the live object graph. Keep concrete adapters there.
- `AppModel` is `@MainActor` and `@Observable`. It owns UI-facing orchestration: hotkey semantics, live language changes, permission refreshes, feedback sounds, indicator transitions, preferences, and Keychain-backed secrets.
- `DictationCoordinator` is `@MainActor` and `@Observable`. It owns the session ID, state machine, recording watchdog, cancellation/stale-session protection, transcription, optional cleanup, delivery, and temporary-file cleanup.
- `ConnectionTestModel` reuses the audio recorder and transcription port but has an independent UI state. Do not allow a connection test and dictation to run together.
- Core dependencies enter through `DictationDependencies`; app-only dependencies enter through `AppDependencies`. Add a protocol/port when behavior needs a test double.
- UI-facing types and all adapters touching AppKit, Accessibility, pasteboard, hotkeys, windows, or permissions stay on `@MainActor`. Domain values crossing concurrency boundaries must be `Sendable`.
- Coordinator lifecycle callbacks drive presentation effects. Keep the indicator and sounds outside `MurmureCore`; the core should not know about panels, AppKit, or localized labels.

## Platform lessons and invariants

### App bundle, signing, and TCC

- A real `.app` bundle is required for windows, global shortcuts, microphone permission, Accessibility permission, localization, Sparkle, and launch-at-login behavior.
- Keep `CFBundleIdentifier` stable (`com.d9beuD.Murmure`) and sign the development app with a stable identity when available. Ad hoc signatures can make macOS treat rebuilds as a different Accessibility client, requiring permission to be renewed.
- Apply `Configuration/Murmure.entitlements` when signing both development and release builds. Missing or inconsistent entitlements/signatures can make TCC permission appear granted while Accessibility calls still fail.
- `run-app.sh` and `build-dmg.sh` must embed `Sparkle.framework`, add `@executable_path/../Frameworks`, copy SPM resource bundles, compile string catalogs, and sign the final hierarchy. Do not “simplify” away those steps.
- After changing packaging, signing, localization, dependencies, or `Info.plist`, assemble with `MURMURE_SKIP_OPEN=1` and run `verify-app-bundle.sh`. It checks Sparkle linkage/rpath, compiled English/French resources, runtime localization lookup, and the code signature.

### Accessibility, insertion, and the listening indicator

- `FocusedTextElementResolver.shared` is the common source of focus truth for delivery and indicator positioning. Keep their candidate-resolution behavior aligned.
- Focus information is unreliable across apps: the system-wide focused element can lag behind the frontmost application, especially in Firefox, Chromium, and Electron. The resolver enables web accessibility, checks application/window focus first, walks editable ancestors, and uses a bounded descendant search. Preserve the traversal bounds and short AX messaging timeout.
- Native editable controls may use `AXSelectedText` replacement. Web editors (`AXGroup`, `AXGenericElement`, or `AXWebArea` ancestry) must use clipboard plus a synthetic Command-V event; direct AX replacement is not dependable for contenteditable controls.
- Never insert through Accessibility into secure/password fields. Copy instead. If focus resolution or paste event posting fails, retain the transcript on the clipboard and return a typed fallback result.
- Caret anchoring is progressively resolved: selected-text bounds, browser text-marker bounds, adjacent-character bounds, focused-control frame, then pointer fallback. The last good non-fallback anchor is retained while the indicator is visible to avoid visual jumps.
- The indicator must remain a borderless, non-activating, click-through `NSPanel`; it must never steal key focus from the destination app. It follows all spaces, clamps to the visible screen, polls position at a bounded interval, and cancels position/audio tasks when hidden.
- Keep indicator logs diagnostic-only: anchor source and safe AX summaries are allowed; focused text, transcripts, and control values are not.

### Localization and preferences

- User-visible strings belong in `Sources/Murmure/Resources/Localizable.xcstrings`; bundle metadata strings belong in `InfoPlist.xcstrings`. Add both English and French translations and extend `LocalizationTests` when adding required keys.
- Resolve explicit app-language strings through `MurmureLocalization` and pass `model.interfaceLocale` into each SwiftUI scene. Using only the process locale or `NSLocalizedString` can prevent live language changes.
- SwiftPM resources live in `Bundle.module`, then inside `Murmure_Murmure.bundle` in the assembled app. Do not assume localized strings are in `Bundle.main`.
- `AppPreferences` uses versioned `Codable` JSON in `UserDefaults` (`currentSchemaVersion`). New fields need safe decoding defaults and migration behavior for existing installations.
- The default cleanup prompt is localizable while custom and legacy prompts must be preserved. Respect `CleanupPromptMode` when changing language or migrating preferences.
- Provider UUIDs identify their Keychain entries. Preserve or deliberately migrate IDs when editing provider configuration; regenerating an ID disconnects the saved API key.

### Privacy, networking, and logs

- API keys are stored only in macOS Keychain, never in `UserDefaults`, source, fixtures, or logs.
- Audio files live only in the temporary directory and must be deleted after success, failure, or cancellation. Do not commit audio artifacts.
- Networking uses an ephemeral `URLSession`: no persistent cache or cookies, and cross-origin redirects are rejected so authorization headers cannot leak to another origin.
- Murmure has no backend of its own. Audio goes only to the configured STT endpoint; transcript text goes to the configured cleanup endpoint only when cleanup is enabled.
- Logs are memory-only. Never log API keys, authorization headers, audio, transcripts, prompts, pasteboard contents, or raw provider bodies. Use redacted safe-error helpers for diagnostics.

## Dependencies

- `KeyboardShortcuts` 1.10.0, exact and tracked in `Package.resolved`.
- `Sparkle` 2.9.5, exact and tracked in `Package.resolved`.
- Networking and audio use Apple frameworks; do not add a third-party HTTP or recording layer without a concrete need.

When changing dependencies, preserve exact pinning unless the task explicitly calls for an upgrade, update `Package.resolved`, and verify the assembled app—not only `swift build`.

## Testing and change discipline

- CI treats warnings as errors and runs on `macos-26`.
- `./Scripts/check-coverage.sh` enforces 85% line coverage for `MurmureCore` and 80% for selected testable application/infrastructure logic.
- Prefer deterministic protocol-backed tests over live microphone, network, Keychain UI, Accessibility prompts, global events, or sleeps. Inject clocks/sleep and use spies/fakes already present in test support.
- Add regression tests for state transitions, cancellation, stale sessions, secret/log redaction, preference decoding, localization keys, AX focus variants, secure-field fallback, web-editor paste, and indicator task/position behavior when those areas change.
- Interactive validation is still required for macOS integration: global key down/up in background apps, microphone and Accessibility prompts, caret placement across native/Chromium/Electron apps, sound feedback, launch at login, and Sparkle update UI.
- Preserve unrelated work in a dirty worktree. Do not commit `.build/`, `.swiftpm/`, `DerivedData/`, app bundles, DMGs, audio, certificates, provisioning profiles, API keys, or notarization credentials.
- Repository audits reject tracked audio/signing artifacts and OpenAI-style secret patterns. Keep `.gitignore` and CI audits aligned when adding generated formats.

## Release

- `./Scripts/release.sh` requires `MURMURE_VERSION`, `MURMURE_BUILD_NUMBER`, `DEVELOPER_ID_CERTIFICATE_BASE64`, `DEVELOPER_ID_CERTIFICATE_PASSWORD`, `BUILD_KEYCHAIN_PASSWORD`, `APP_STORE_CONNECT_KEY_BASE64`, `APP_STORE_CONNECT_KEY_ID`, and `APP_STORE_CONNECT_ISSUER_ID`.
- `MURMURE_VERSION` is a semantic version without the `v` prefix; the Git tag uses `v`. `MURMURE_BUILD_NUMBER` is the monotonic Sparkle bundle version.
- Release builds use Hardened Runtime, the same entitlements and embedded resources as development builds, Developer ID signing, notarization, stapling, DMG creation, and SHA-256 output.
- The manual GitHub Actions release workflow also generates and signs `appcast.xml`, uploads it with the DMG, and creates the GitHub release. GitHub reports the DMG's SHA-256 digest. Do not publish a hand-written appcast.
- Keep `SUFeedURL` and `SUPublicEDKey` in `Configuration/Info.plist` valid; the release script rejects placeholders. Follow `docs/RELEASE_CHECKLIST.md` for the human validation steps.
