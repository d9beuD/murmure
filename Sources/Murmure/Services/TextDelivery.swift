import AppKit
import CoreGraphics
import MurmureCore

@MainActor
final class TextDelivery: TextDelivering {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyAndPaste(_ text: String) {
        copy(text)

        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyCodeV: CGKeyCode = 9
        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: true
        )
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: false
        )

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
