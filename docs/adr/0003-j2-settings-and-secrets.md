# ADR 0003 — J2 Settings and Secrets

Status: implemented, awaiting interactive Xcode validation

## Decision

STT and TTT configurations are `Codable` values in `MurmureCore`. `AppPreferences` carries a schema number (currently 4, since J7 preferences were added) and is encoded as a single JSON value in `UserDefaults`. An unknown version is ignored and falls back to defaults; future migrations will have a single entry point.

API keys are not part of `AppPreferences`. `KeychainStore` stores them as one generic password under the `com.d9beuD.Murmure` service; its JSON content maps each connection UUID to its key. An empty key is removed from this content. Keychain errors are reduced to a system status and never reveal the value.

At startup, the secrets for STT and TTT profiles are read from one JSON-encoded Keychain entry so the Keychain is queried only once. Missing profiles are treated as empty keys. Entries from previous versions, which stored one key per profile UUID, are read one last time and then migrated automatically to this single entry.

The Settings view exposes STT and TTT parameters, Responses or Chat Completions format, the cleanup prompt, the fallback-to-raw-text policy, delivery mode, and authentication information. Changes are saved automatically; no network call is made at this stage.

## Completed validation

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

Actual verification of Keychain behavior, the Settings window, and the absence of secrets in the bundle must be performed with a signed Xcode target on macOS 26.
