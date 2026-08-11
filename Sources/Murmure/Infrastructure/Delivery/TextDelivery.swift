import AppKit
import CoreGraphics
import MurmureCore
import ApplicationServices

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

    func deliver(_ text: String, mode: OutputMode) -> TextDeliveryResult {
        guard mode == .paste else {
            copy(text)
            return .copied
        }

        let trustedOptions = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        guard AXIsProcessTrustedWithOptions(trustedOptions) else {
            copy(text)
            return .fallbackCopied(reason: "Accessibility permission missing")
        }

        guard let focusedElement = focusedElement() else {
            copyAndPaste(text)
            return .fallbackCopied(reason: "active field not found")
        }

        guard let role = role(of: focusedElement) else {
            copyAndPaste(text)
            return .fallbackCopied(reason: "unknown active field role")
        }

        if role == "AXSecureTextField" || role == "AXPasswordField" {
            copy(text)
            return .secureFieldCopied
        }

        let textRoles = ["AXTextField", "AXTextArea", "AXSearchField", "AXComboBox", "AXWebArea"]
        guard textRoles.contains(role) else {
            copy(text)
            return .fallbackCopied(reason: "active field is not editable")
        }

        var isSettable = DarwinBoolean(false)
        let selectedTextAttribute = kAXSelectedTextAttribute as CFString
        AXUIElementIsAttributeSettable(focusedElement, selectedTextAttribute, &isSettable)
        if isSettable.boolValue,
           AXUIElementSetAttributeValue(focusedElement, selectedTextAttribute, text as CFTypeRef) == .success {
            return .inserted
        }

        copyAndPaste(text)
        return .fallbackCopied(reason: "Accessibility insertion rejected")
    }

    private func focusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )
        guard result == .success, let value else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }
}
