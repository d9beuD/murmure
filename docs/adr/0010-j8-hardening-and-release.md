# ADR 0010 — J8 Hardening and Release

Status: implemented, awaiting Apple validation of the first release

## Decision

Network transports use an ephemeral session and block every redirect that changes the scheme, host, or port. The ATS exception is limited to local networking so loopback HTTP endpoints remain available without allowing HTTP traffic to the internet.

Logs no longer write `localizedDescription` for unknown errors. STT and TTT services provide a redacted diagnostic message, optionally with an HTTP status code, while provider-supplied details remain visible only in the active error interface.

A test target covers preference migrations, endpoint normalization, log protection, and an injected dictation pipeline. CI builds with warnings treated as errors, runs these tests, and rejects known secret, signature, and audio-recording formats.

`Scripts/release.sh` builds a Release bundle, applies Hardened Runtime, signs with a Developer ID identity supplied by the environment, produces a DMG, reports its SHA-256 digest, and can submit the archive to `notarytool` using a temporarily reconstructed App Store Connect Team API key.

## Remaining final validation

Strict compilation and tests are validated with Xcode. The first real signing and notarization remain to be performed with the maintainer's Developer ID certificate and App Store Connect Team API key; the process is described in the release checklist.
