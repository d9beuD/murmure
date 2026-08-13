import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class SystemAccessibilityClient: AccessibilityClient {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func systemWideElement() -> AccessibilityElement {
        AccessibilityElement(rawElement: AXUIElementCreateSystemWide())
    }

    func frontmostApplication() -> AccessibilityElement? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        return applicationElement(processIdentifier: application.processIdentifier)
    }

    func applicationElement(processIdentifier: pid_t) -> AccessibilityElement {
        AccessibilityElement(rawElement: AXUIElementCreateApplication(processIdentifier))
    }

    func focusedElement(in element: AccessibilityElement) -> AccessibilityElement? {
        elementAttribute(kAXFocusedUIElementAttribute as String, of: element)
    }

    func focusedApplication(in element: AccessibilityElement) -> AccessibilityElement? {
        elementAttribute(kAXFocusedApplicationAttribute as String, of: element)
    }

    func focusedWindow(in element: AccessibilityElement) -> AccessibilityElement? {
        elementAttribute(kAXFocusedWindowAttribute as String, of: element)
    }

    func parent(of element: AccessibilityElement) -> AccessibilityElement? {
        elementAttribute(kAXParentAttribute as String, of: element)
    }

    func editableAncestor(of element: AccessibilityElement) -> AccessibilityElement? {
        elementAttribute(kAXEditableAncestorAttribute as String, of: element)
    }

    func highestEditableAncestor(of element: AccessibilityElement) -> AccessibilityElement? {
        elementAttribute(kAXHighestEditableAncestorAttribute as String, of: element)
    }

    func children(of element: AccessibilityElement) -> [AccessibilityElement] {
        elementArrayAttribute(kAXChildrenAttribute as String, of: element)
    }

    func visibleChildren(of element: AccessibilityElement) -> [AccessibilityElement] {
        elementArrayAttribute(kAXVisibleChildrenAttribute as String, of: element)
    }

    func contents(of element: AccessibilityElement) -> [AccessibilityElement] {
        elementArrayAttribute(kAXContentsAttribute as String, of: element)
    }

    func setMessagingTimeout(_ timeout: Float, for element: AccessibilityElement) {
        guard let raw = element.raw else { return }
        _ = AXUIElementSetMessagingTimeout(raw, timeout)
    }

    func enableWebAccessibility(in element: AccessibilityElement) {
        guard let raw = element.raw else { return }
        _ = AXUIElementSetAttributeValue(
            raw,
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementSetAttributeValue(
            raw,
            "AXEnhancedUserInterface" as CFString,
            kCFBooleanTrue
        )
    }

    func role(of element: AccessibilityElement) -> String? {
        stringAttribute(kAXRoleAttribute as String, of: element)
    }

    func subrole(of element: AccessibilityElement) -> String? {
        stringAttribute(kAXSubroleAttribute as String, of: element)
    }

    func isEditable(of element: AccessibilityElement) -> Bool {
        booleanAttribute("AXEditable", of: element)
            || booleanAttribute(kAXIsEditableAttribute as String, of: element)
    }

    func hasAttribute(_ attribute: String, in element: AccessibilityElement) -> Bool {
        guard let raw = element.raw else { return false }
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(raw, attribute as CFString, &value) == .success
    }

    func selectedTextRange(of element: AccessibilityElement) -> CFRange? {
        guard let raw = element.raw else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            raw,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let accessibilityValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(accessibilityValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(accessibilityValue, .cfRange, &range),
              range.location >= 0,
              range.length >= 0,
              range.location <= CFIndex.max - range.length
        else {
            return nil
        }
        return range
    }

    func textMarkerCaretBounds(of element: AccessibilityElement) -> CGRect? {
        guard let raw = element.raw else { return nil }
        let markerAttribute = "AXSelectedTextMarkerRange" as CFString
        let boundsAttribute = "AXBoundsForTextMarkerRange" as CFString

        var markerRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, markerAttribute, &markerRange) == .success,
              let markerRange
        else {
            return nil
        }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            raw,
            boundsAttribute,
            markerRange,
            &boundsValue
        ) == .success,
        let boundsValue
        else {
            return nil
        }
        return cgRect(from: boundsValue)
    }

    func bounds(for range: CFRange, in element: AccessibilityElement) -> CGRect? {
        guard let raw = element.raw else { return nil }
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            raw,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        ) == .success,
        let boundsValue
        else {
            return nil
        }
        return cgRect(from: boundsValue)
    }

    func frame(of element: AccessibilityElement) -> CGRect? {
        guard let raw = element.raw else { return nil }
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            raw,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            raw,
            kAXSizeAttribute as CFString,
            &sizeValue
        ) == .success,
        let positionValue,
        let sizeValue,
        let position = cgPoint(from: positionValue),
        let size = cgSize(from: sizeValue),
        size.width > 0,
        size.height > 0
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    func isAttributeSettable(_ attribute: String, in element: AccessibilityElement) -> Bool {
        guard let raw = element.raw else { return false }
        var settable = DarwinBoolean(false)
        _ = AXUIElementIsAttributeSettable(raw, attribute as CFString, &settable)
        return settable.boolValue
    }

    func replaceSelectedText(_ text: String, in element: AccessibilityElement) -> Bool {
        guard let raw = element.raw else { return false }
        let attribute = kAXSelectedTextAttribute as CFString
        guard isAttributeSettable(kAXSelectedTextAttribute as String, in: element) else {
            return false
        }
        return AXUIElementSetAttributeValue(raw, attribute, text as CFTypeRef) == .success
    }

    private func elementAttribute(
        _ attribute: String,
        of element: AccessibilityElement
    ) -> AccessibilityElement? {
        guard let raw = element.raw else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return AccessibilityElement(rawElement: unsafeDowncast(value, to: AXUIElement.self))
    }

    private func elementArrayAttribute(
        _ attribute: String,
        of element: AccessibilityElement
    ) -> [AccessibilityElement] {
        guard let raw = element.raw else { return [] }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, attribute as CFString, &value) == .success,
              let value
        else {
            return []
        }

        if CFGetTypeID(value) == AXUIElementGetTypeID() {
            return [AccessibilityElement(rawElement: unsafeDowncast(value, to: AXUIElement.self))]
        }
        guard CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
        let values = unsafeDowncast(value, to: CFArray.self) as [AnyObject]
        return values.compactMap { candidate in
            guard CFGetTypeID(candidate) == AXUIElementGetTypeID() else { return nil }
            return AccessibilityElement(rawElement: unsafeDowncast(candidate, to: AXUIElement.self))
        }
    }

    private func stringAttribute(_ attribute: String, of element: AccessibilityElement) -> String? {
        guard let raw = element.raw else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func booleanAttribute(_ attribute: String, of element: AccessibilityElement) -> Bool {
        guard let raw = element.raw else { return false }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(raw, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == CFBooleanGetTypeID()
        else {
            return false
        }
        return CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self))
    }

    private func cgPoint(from value: CFTypeRef) -> CGPoint? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let accessibilityValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(accessibilityValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(accessibilityValue, .cgPoint, &point) ? point : nil
    }

    private func cgSize(from value: CFTypeRef) -> CGSize? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let accessibilityValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(accessibilityValue) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(accessibilityValue, .cgSize, &size) ? size : nil
    }

    private func cgRect(from value: CFTypeRef) -> CGRect? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let accessibilityValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(accessibilityValue) == .cgRect else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(accessibilityValue, .cgRect, &rect),
              rect.height > 0,
              rect.origin.x.isFinite,
              rect.origin.y.isFinite
        else {
            return nil
        }
        return rect
    }
}
