# ADR 0014: Shared provider catalogue and local Apple models

## Decision

Persist a shared catalogue of providers rather than one STT configuration and
one cleanup configuration. A catalogue entry is either the singleton local
Apple provider or a remote profile identified by a stable UUID. Remote profiles
share their URL, authentication, and Keychain secret while keeping their STT and
TTT routes, models, and TTT API format independent.

New installations have no selected providers and cleanup is disabled. Schema 8
preferences are decoded into two OpenAI-compatible profiles, retaining their
UUIDs so existing Keychain records remain addressable. A UUID collision receives
a new cleanup UUID rather than overwriting the STT entry.

## Routing and privacy

The composition root routes resolved requests to either existing remote OpenAI
adapters or Apple Speech/Foundation Models adapters. Apple requests never route
through `DictationTranscriber` or a remote fallback. Speech availability and
asset reservation are checked before microphone permission; Foundation Models
availability is checked before local cleanup. Shared cleanup instructions and
echo protection apply to both local and remote text transformations.

The presentation layer owns provider editing and safe alerts. Core exposes only
typed targets and availability errors. The Keychain store is written as a full
UUID-to-secret map, and deleting a profile removes its secret before the
catalogue mutation is committed.

## Consequences

The settings UI can independently select STT and TTT capabilities, safely keep
multiple remote credentials, and offer explicit in-memory model discovery.
Apple availability remains device and locale dependent, so manual signed-app
validation is required for asset downloads and Apple Intelligence states.
