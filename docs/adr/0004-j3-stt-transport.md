# ADR 0004 — J3 STT Vertical Slice

Status: implemented, awaiting real microphone and provider validation

## Decision

Capture remains a 16 kHz, 16-bit, mono PCM WAV. After recording stops, `DictationCoordinator` creates an identified session, transitions to `transcribing`, then delegates to `OpenAITranscriptionService`. The service uses an ephemeral `URLSession` and builds the `multipart/form-data` request itself without a third-party SDK.

The primary contract is `/audio/transcriptions`: `file`, `model`, `prompt`, and optional language fields. For `gpt-transcribe`, the language is sent in `languages[]`; Whisper-compatible models receive the singular `language` field. JSON responses containing `text` and raw text bodies are accepted. Request bodies, responses, and keys are never logged.

Every session deletes its WAV in a `defer`, including on cancellation, HTTP error, or decoding failure. A response arriving after cancellation is ignored through the session identifier.

## Completed validation

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

Microphone permission, sending to a real endpoint, and insertion into a target app require a signed `.app`, configured macOS TCC permissions, and a test provider key.
