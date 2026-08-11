# ADR 0009 — J7 Onboarding and Polish

Status: implemented, awaiting interactive macOS validation

## Decision

A new user receives a five-step SwiftUI assistant: data-flow explanation, STT configuration, explicit test, global shortcut, then output and general preferences. Existing installations are considered already configured when migrating from schema 3 to 4 so their use is not interrupted.

The connection test is never implicit: it opens the microphone, asks the user to record a phrase, and reuses the normal STT transport. The temporary file is deleted at the end of the test, and only the character count is displayed or logged.

Microphone and Accessibility permissions are shown in Settings. Accessibility is requested only through an explicit action and remains optional: the clipboard is the safe fallback. Launch at login uses `SMAppService.mainApp`; a failure is displayed in Settings without changing the persisted preference.

Start and end sounds can be enabled and contain no dictation data. The interface and user documentation are in English. Log events also remain in English to preserve a consistent diagnostic format.

## Completed validation

```text
swift build -Xswiftc -warnings-as-errors
```

Remaining manual validation covers the guide opening automatically on a clean installation, launch-at-login registration from a signed bundle, system permission dialogs, sounds, and a real STT test.
