# ADR 0006 — Live Logs

Status: implemented

## Decision

`AppLogStore` is an observable in-memory object injected by the application composition root and supplied to the core through the `LogWriting` port. It writes nothing to `UserDefaults`, a file, or Keychain. Lines never contain an API key, request body, or transcribed text.

The SwiftUI `LogsView` window is accessible from the menu bar. It displays entries in a white monospaced font on a black background, with local dates to millisecond precision and automatic scrolling to the latest entry. A button clears the current content.

The coordinator currently produces recording and STT events: start, end, upload size, then the number of characters received. TTT enrichment events will be added when `CleanupService` is implemented in milestone J5.
