import AppKit
import CoreGraphics

@MainActor
protocol PasteEventPosting: AnyObject {
    func postPaste() -> Bool
}

@MainActor
final class SystemPasteEventPoster: PasteEventPosting {
    func postPaste() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }

        let keyCodeV: CGKeyCode = 9
        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: true
        ),
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: false
        ) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        if let processIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            keyDown.postToPid(processIdentifier)
            keyUp.postToPid(processIdentifier)
        } else {
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
        return true
    }
}
