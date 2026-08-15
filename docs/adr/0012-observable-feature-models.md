# ADR 0012 — Observable feature models and modularization boundaries

Status: implemented

## Decision

`AppModel` is the application root and owns no feature state of its own. It composes four shared observable models:

- `PreferencesModel` is the single source of truth for `AppPreferences` and the two Keychain-backed API keys. UserDefaults and Keychain writes are independent and lifecycle flushes are explicit.
- `DictationSessionModel` owns dictation and connection-test workflow presentation effects.
- `PermissionsModel` owns permission snapshots, polling, and permission requests.
- `PromptLibraryModel` owns prompt validation, CRUD, and selection. Navigation, alerts, and unsaved drafts remain view-owned state.

Scenes inject these instances through SwiftUI’s environment. Views read with `@Environment` and use `@Bindable` only when editing. The composition root creates the instances once, so menu-bar, settings, onboarding, and auxiliary windows observe the same references.

The production dependency direction is one-way:

```text
Entrevoix (SwiftUI, AppKit, networking, persistence adapters)
        └──> EntrevoixCore (domain, orchestration, ports)
```

`EntrevoixCore` must not import or reference AppKit. Presentation effects are expressed as typed events and interpreted by the macOS target.

## Target and module boundary

The project intentionally maintains exactly two production targets: `EntrevoixCore` and `Entrevoix`. A third target is permitted only when a subsystem has an independently managed lifecycle, meaningful reuse, or a genuinely independent dependency boundary. File size alone is not sufficient justification for another target.

This keeps SwiftPM packaging, signing, localization resources, and the composition root predictable while still allowing feature-level files and observable models to evolve independently.

## Consequences

The design follows Apple’s SwiftUI guidance around a single source of truth, `@Observable` reference models owned and shared by the app, environment propagation, and lightweight declarative views. MVVM or Clean Architecture is not treated as an Apple-mandated pattern; the Core ports and composition root remain deliberate project-level boundaries.

Preferences schema version 8, provider UUIDs, storage locations, network formats, audio formats, delivery behavior, and privacy guarantees remain compatible.
