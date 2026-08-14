# ADR 0008 — J6 Cross-Application Text Delivery

Status: implemented, awaiting manual target-application validation

## Decision

Delivery is triggered by the coordinator after STT and optional TTT. The `clipboard` mode writes text to `NSPasteboard`. The `paste` mode requests Accessibility permission, inspects the focused element, and tries to replace selected text through `kAXSelectedTextAttribute`.

`AXSecureTextField` and `AXPasswordField` fields never receive synthetic keystrokes: text is only copied. If permission is missing, the element is not editable, or AX insertion fails, Entrevoix keeps the result on the clipboard and uses `⌘V` only when a non-secure text field has been identified. Every result is logged without including the text.

Delivery persists nothing and does not replace the in-memory transcript. Manual copying through the delivery service remains possible for future screens.

## Completed validation

```text
swift build
swift build -Xswiftc -warnings-as-errors
```

Final validation must cover Notes, Safari, Terminal, and a code editor, with and without Accessibility permission, as well as a password field.
