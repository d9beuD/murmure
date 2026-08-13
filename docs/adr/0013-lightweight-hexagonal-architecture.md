# ADR 0013 — Lightweight hexagonal architecture

Status: implemented

## Decision

Murmure retains exactly two production SwiftPM targets. `MurmureCore` contains
only `Domain` and `Application`, including outbound ports, pure rules, use cases,
typed lifecycle events, and immutable `Sendable` snapshots. It imports neither
Observation nor UI/platform/infrastructure frameworks.

The executable target contains three logical layers. `App` owns the entry point,
scene wiring, diagnostics, and the sole composition root. `Presentation` owns
SwiftUI views, `@MainActor @Observable` Stores, localization adaptations, and
visual AppKit presentation. `Adapters` owns concrete macOS, network, audio,
delivery, persistence, Keychain, and hotkey integrations.

Application coordinators are non-observable and publish typed snapshots and
lifecycle events. Presentation Stores observe these callbacks and remain the
single owner of UI state. `AppEnvironment` is the non-observable composition
result shared by scenes.

## Consequences

The dependency direction is `Presentation -> Application -> Domain`, with
`Adapters -> Application / Domain`; `App` may reference every layer only to
assemble it. Existing preference schema, Keychain identifiers, network and audio
formats, localization behavior, and privacy guarantees remain unchanged.

`Scripts/check-architecture.sh`, run in CI and release builds, prevents technical
imports or observation state in `MurmureCore` and rejects concrete adapter
construction outside `CompositionRoot`.

## Supersedes

This ADR supersedes the target/layout portions of ADR 0011 and ADR 0012. Their
compatibility, privacy, test, and single-source-of-truth decisions remain in force.
