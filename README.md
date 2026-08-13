# Murmure

Murmure is a macOS voice dictation app designed to live in the menu bar. It uses STT and TTT endpoints compatible with the OpenAI API format.

## Project status

Milestone J8 provides the current Swift 6 app targeting macOS 26. J1 is code-complete from source, build, test, and bundle-script evidence, but final menu-bar-only runtime validation requires an interactive Xcode-signed `.app` launch. Some J0 checks still require manual, interactive macOS validation, especially global events, cross-app paste, and sandbox behavior. Current feature set includes:

- a `Murmure` executable target;
- a `MurmureCore` domain library;
- a composition root that injects shared audio, permission, networking, persistence,
  delivery, and feedback adapters;
- `MenuBarExtra` and `Settings` interfaces;
- injectable coordination;
- audio capture and clipboard delivery inherited from the J0 spike;
- push-to-talk and toggle global shortcuts;
- STT and TTT settings editable from the SwiftUI Settings window;
- versioned JSON persistence in `UserDefaults` for non-sensitive settings;
- API keys stored only in the macOS Keychain;
- local validation of endpoints and models;
- microphone permission handling;
- WAV recording followed by multipart upload to `/audio/transcriptions`;
- JSON and plain-text response parsing with explicit HTTP errors;
- temporary-file deletion after every transcription;
- a state machine protected against stale sessions;
- typed dictation and connection-test failures with safe diagnostic logging;
- push-to-talk and toggle modes with debounce;
- a minimum duration of 250 ms and a 10-minute watchdog;
- safe cancellation while requesting microphone access or transcribing;
- an in-memory live log window;
- optional cleanup through the Responses API or Chat Completions;
- fallback to the raw transcript when TTT fails;
- automatic delivery to the clipboard or active field;
- safe Accessibility insertion with a controlled fallback;
- a complete first-launch assistant in English;
- an explicit STT connection test using a short recording;
- Microphone and Accessibility permission status and requests;
- optional launch at login and sound feedback;
- help available from the menu bar;
- ephemeral networking that rejects cross-origin redirects;
- error logs with provider responses redacted;
- domain, application, and infrastructure tests with coverage thresholds in CI;
- a script that prepares a signed, notarizable archive and reports its SHA-256 digest.

## First-time setup

On first launch, Murmure opens a guide for configuring an STT provider, choosing
a global shortcut, testing the connection, and selecting an output mode. All of
these settings remain editable from **Settings** in the menu bar.

The STT test requests microphone access, records a short phrase, then sends the
audio file to the configured provider. It never runs in the background.

**Insert Automatically** requires Accessibility permission. Without it—and for
secure fields—Murmure always copies the result to the clipboard instead.

## Privacy

- API keys are stored in the macOS Keychain, never in `UserDefaults` or logs.
- Audio is created in the macOS temporary directory and deleted after every
  transcription, whether it succeeds, fails, or is canceled.
- Murmure has no accounts or servers of its own: audio and, when enabled, the
  transcript are sent only to the STT and TTT endpoints you choose.
- The Logs window keeps events only in memory and displays no secrets, audio,
  transcripts, or prompts.

## Local development

With Xcode 26 (including `xcstringstool`), Swift 6.3, and a macOS 26 SDK:

```shell
swift build
./Scripts/run-app.sh
```

The localization catalogs are compiled while assembling the `.app`, so the
Command Line Tools alone are not sufficient for launching or releasing the
localized bundle. Select the full Xcode toolchain with `xcode-select` (or
`DEVELOPER_DIR`) before running the app scripts.

The script builds a real `Murmure.app` bundle, applies `Info.plist`, signs it
locally, and launches it through LaunchServices. Use this script to test the UI,
windows, shortcuts, and permissions. `swift run Murmure` produces only a raw
executable without macOS application metadata and is suitable only for basic
diagnostics.

To assemble and verify the development bundle without opening it, run:

```shell
MURMURE_SKIP_OPEN=1 ./Scripts/run-app.sh
./Scripts/verify-app-bundle.sh "$(swift build --show-bin-path)/Murmure.app"
```

The verification checks that the app contains `Sparkle.framework`, has the
correct framework search path, and passes code-signature validation.

The global-shortcut handler is installed after the macOS event loop starts so
saved shortcuts remain active after relaunching the app.

Tests require a full Xcode installation (the Command Line Tools do not include
XCTest):

```shell
swift test -Xswiftc -warnings-as-errors
```

## Launch at login

The option is available under **Settings > General**. macOS may request
permission or require the application to be installed as a signed bundle; the
development script is not the final distribution method.

## Preparing a release

On a machine with Xcode and a Developer ID identity, `Scripts/release.sh`
produces a DMG and reports its SHA-256 digest. The GitHub **Release** workflow can be
run manually to produce a DMG, attach it to a new release, sign it, and notarize
it with an App Store Connect Team API key. See the detailed
[release checklist](docs/RELEASE_CHECKLIST.md).

## License

Murmure is distributed under the MIT License. See [LICENSE](LICENSE).
Dependency notices are available in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
