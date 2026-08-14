# ADR 0005 — J4 Coordinator and Shortcuts

Status: implemented, awaiting interactive shortcut validation

## Decision

A session receives a UUID as soon as microphone permission is requested. Every task—permission, recording, and transcription—checks this identifier before changing state. Cancellation therefore immediately invalidates late results.

Push-to-talk mode stops capture on release and cancels a permission request if the key is released too soon. Toggle mode reacts only to `keyDown`: the first press starts, and the second stops. Repeated events and closely spaced presses are filtered through a 150 ms debounce.

A recording shorter than 250 ms is deleted without a network request. A ten-minute watchdog triggers a normal stop if the system never delivers `keyUp`. The mode can only be changed while the coordinator is idle and is now persisted in preference schema 3.

## Completed validation

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

The keyboard scenario matrix (short press, hold, toggle, repeat, cancellation, and lost `keyUp`) must be run in a graphical macOS session with the `Entrevoix.app` bundle.
