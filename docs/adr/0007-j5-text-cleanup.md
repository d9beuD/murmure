# ADR 0007 — J5 TTT Cleanup

Status: implemented, awaiting real provider validation

## Decision

After a successful STT transcription, cleanup is optional. The active prompt is selected from the persisted prompt library. The Responses API receives its `instructions` and `input` for the raw text; Chat Completions receives the same instructions as a `system` message followed by a `user` message. Requests specify `store: false` and use no conversational state. If cleanup is enabled while the library has no active prompt, Entrevoix skips TTT and delivers the raw STT transcript.

`OpenAITextCleanupService` accepts Responses API output by aggregating all `output_text` content instead of assuming the first `output` item is text. For Chat Completions, it accepts both plain text content and arrays of text parts.

The `useRawTranscript` policy retains the STT text if cleanup fails. The `stop` policy surfaces the error while keeping the raw transcript in memory for later copying. In both cases, the temporary audio file is deleted.

Logs indicate the upload to the TTT provider, the enhanced response length, and errors without writing prompts, keys, or content to persistent storage.

## Completed validation

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

A test with real Responses and Chat Completions endpoints remains to be performed using test keys and non-sensitive dictation text.
