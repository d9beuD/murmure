# ADR 0011 — Core ports, application orchestration, and composition root

Status: implemented

## Decision

Entrevoix keeps two production SwiftPM targets. `EntrevoixCore` now contains domain values, application orchestration, explicit ports, typed dictation failures, and log-safety helpers. `Entrevoix` contains SwiftUI features and all macOS/network/persistence adapters.

`CompositionRoot` is the only production construction point. It creates shared audio, permission, transport, transcription, cleanup, delivery, persistence, Keychain, shortcut, feedback, and logging implementations, then injects them into `AppModel`, `DictationCoordinator`, and `ConnectionTestModel`.

The coordinator receives a `DictationRequest` snapshot instead of a long parameter list. Microphone permission is a separate port from audio capture. `UserDefaultsPreferencesStore` and the observable `AppLogStore` are application infrastructure; `EntrevoixCore` exposes only `PreferencesStoring` and `LogWriting`.

## Compatibility and privacy

This is a source-compatible change only within the repository; the public `EntrevoixCore` API may change. The preferences schema, UserDefaults key, Keychain service/accounts, network wire formats, audio format, and log redaction rules are unchanged. Request values containing API keys are `Sendable`, are not persisted, and are never logged.

## Verification

`EntrevoixCoreTests` covers domain and coordinator behavior. `EntrevoixTests` covers application models, connection tests, persistence, Keychain, transport safety, and provider clients. CI enforces 85% core coverage and 80% selected application-logic coverage.
