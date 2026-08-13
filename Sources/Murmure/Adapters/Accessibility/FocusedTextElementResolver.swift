import AppKit
import ApplicationServices
import CoreGraphics

struct AccessibilityElement: Hashable {
    private let rawElement: AXUIElement?
    private let syntheticID: String?

    init(rawElement: AXUIElement) {
        self.rawElement = rawElement
        syntheticID = nil
    }

    init(syntheticID: String) {
        rawElement = nil
        self.syntheticID = syntheticID
    }

    static func == (lhs: AccessibilityElement, rhs: AccessibilityElement) -> Bool {
        switch (lhs.rawElement, rhs.rawElement) {
        case let (lhsRaw?, rhsRaw?):
            CFEqual(lhsRaw, rhsRaw)
        case (nil, nil):
            lhs.syntheticID == rhs.syntheticID
        default:
            false
        }
    }

    func hash(into hasher: inout Hasher) {
        if let rawElement {
            hasher.combine(CFHash(rawElement))
        } else {
            hasher.combine(syntheticID)
        }
    }

    var raw: AXUIElement? { rawElement }
}

@MainActor
protocol AccessibilityClient: AnyObject {
    func isTrusted() -> Bool
    func systemWideElement() -> AccessibilityElement
    func frontmostApplication() -> AccessibilityElement?
    func applicationElement(processIdentifier: pid_t) -> AccessibilityElement

    func focusedElement(in element: AccessibilityElement) -> AccessibilityElement?
    func focusedApplication(in element: AccessibilityElement) -> AccessibilityElement?
    func focusedWindow(in element: AccessibilityElement) -> AccessibilityElement?
    func parent(of element: AccessibilityElement) -> AccessibilityElement?
    func editableAncestor(of element: AccessibilityElement) -> AccessibilityElement?
    func highestEditableAncestor(of element: AccessibilityElement) -> AccessibilityElement?
    func children(of element: AccessibilityElement) -> [AccessibilityElement]
    func visibleChildren(of element: AccessibilityElement) -> [AccessibilityElement]
    func contents(of element: AccessibilityElement) -> [AccessibilityElement]

    func setMessagingTimeout(_ timeout: Float, for element: AccessibilityElement)
    func enableWebAccessibility(in element: AccessibilityElement)

    func role(of element: AccessibilityElement) -> String?
    func subrole(of element: AccessibilityElement) -> String?
    func isEditable(of element: AccessibilityElement) -> Bool
    func hasAttribute(_ attribute: String, in element: AccessibilityElement) -> Bool
    func selectedTextRange(of element: AccessibilityElement) -> CFRange?
    func textMarkerCaretBounds(of element: AccessibilityElement) -> CGRect?
    func bounds(for range: CFRange, in element: AccessibilityElement) -> CGRect?
    func frame(of element: AccessibilityElement) -> CGRect?

    func isAttributeSettable(_ attribute: String, in element: AccessibilityElement) -> Bool
    func replaceSelectedText(_ text: String, in element: AccessibilityElement) -> Bool
}

@MainActor
struct FocusedTextElement {
    let element: AccessibilityElement
    let role: String?
    let subrole: String?
    let isEditable: Bool
    let isWebEditor: Bool

    var isSecure: Bool {
        role == "AXSecureTextField"
            || role == "AXPasswordField"
            || subrole == kAXSecureTextFieldSubrole as String
    }
}

@MainActor
final class FocusedTextElementResolver {
    static let shared = FocusedTextElementResolver()
    private static let ancestorLimit = 8
    private static let candidateLimit = 384

    let client: any AccessibilityClient

    init(client: any AccessibilityClient = SystemAccessibilityClient()) {
        self.client = client
    }

    func resolve() -> FocusedTextElement? {
        focusedElementCandidates()
            .first(where: isTextInput)
            .map { element in
                let isEditable = client.isEditable(of: element)
                    || client.isAttributeSettable(
                        kAXSelectedTextAttribute as String,
                        in: element
                    )
                return FocusedTextElement(
                    element: element,
                    role: client.role(of: element),
                    subrole: client.subrole(of: element),
                    isEditable: isEditable,
                    isWebEditor: isWebEditor(element)
                )
            }
    }

    func focusedElementCandidates() -> [AccessibilityElement] {
        guard client.isTrusted() else { return [] }
        let systemWideElement = client.systemWideElement()
        let systemFocusedElement = client.focusedElement(in: systemWideElement)
        var candidates: [AccessibilityElement] = []

        var applications: [AccessibilityElement] = []
        if let focusedApplication = client.focusedApplication(in: systemWideElement) {
            append(focusedApplication, to: &applications)
        }
        if let frontmostApplication = client.frontmostApplication() {
            append(frontmostApplication, to: &applications)
        }

        var traversalRoots: [AccessibilityElement] = []
        for application in applications {
            client.setMessagingTimeout(0.2, for: application)
            client.enableWebAccessibility(in: application)
            if let focusedElement = client.focusedElement(in: application) {
                append(focusedElement, to: &candidates)
            }
            if let focusedWindow = client.focusedWindow(in: application) {
                client.enableWebAccessibility(in: focusedWindow)
                if let focusedElement = client.focusedElement(in: focusedWindow) {
                    append(focusedElement, to: &candidates)
                }
                append(focusedWindow, to: &traversalRoots)
            }
            append(application, to: &traversalRoots)
        }
        candidates.append(contentsOf: traversalRoots.filter { !candidates.contains($0) })

        appendAncestors(to: &candidates)

        if candidates.contains(where: isPromisingTextInput) {
            return candidates
        }

        // The system-wide focus can lag behind the application/window focus in
        // Firefox and Chromium. Search the freshly activated application tree
        // first so a stale address-bar element cannot win over a web editor.
        let traversalLimit = systemFocusedElement == nil
            ? Self.candidateLimit
            : Self.candidateLimit - 4
        if traverseDescendants(of: &candidates, limit: traversalLimit) {
            return candidates
        }

        if let systemFocusedElement {
            append(systemFocusedElement, to: &candidates)
            appendDirectAncestors(of: systemFocusedElement, to: &candidates)
        }
        return candidates
    }

    func isTextInput(_ element: AccessibilityElement) -> Bool {
        let role = client.role(of: element)
        if client.subrole(of: element) == kAXSecureTextFieldSubrole as String {
            return true
        }
        let textRoles = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXSearchField",
            kAXComboBoxRole as String,
            "AXSecureTextField",
            "AXPasswordField"
        ]
        if let role, textRoles.contains(role) {
            return true
        }
        return client.isEditable(of: element)
            || client.hasAttribute(kAXSelectedTextRangeAttribute as String, in: element)
            || client.hasAttribute("AXSelectedTextMarkerRange", in: element)
    }

    func isPromisingTextInput(_ element: AccessibilityElement) -> Bool {
        isTextInput(element)
    }

    func isWebEditor(_ element: AccessibilityElement) -> Bool {
        var currentElement: AccessibilityElement? = element
        for _ in 0...Self.ancestorLimit {
            guard let element = currentElement else { return false }
            let role = client.role(of: element)
            if role == "AXGroup" || role == "AXGenericElement" || role == "AXWebArea" {
                return true
            }
            currentElement = client.parent(of: element)
        }
        return false
    }

    func directCaretPoint(in element: AccessibilityElement) -> NSPoint? {
        guard let selectedRange = client.selectedTextRange(of: element) else { return nil }
        let location = selectedRange.location + selectedRange.length
        guard location >= 0, location <= CFIndex.max else { return nil }
        return client.bounds(
            for: CFRange(location: location, length: 0),
            in: element
        )
        .flatMap(appKitRect(from:))?
        .topCenter
    }

    func textMarkerCaretPoint(in element: AccessibilityElement) -> NSPoint? {
        client.textMarkerCaretBounds(of: element)
            .flatMap(appKitRect(from:))?
            .topCenter
    }

    func adjacentCharacterCaretPoint(in element: AccessibilityElement) -> NSPoint? {
        guard let selectedRange = client.selectedTextRange(of: element) else { return nil }
        let caretLocation = selectedRange.location + selectedRange.length
        if let nextBounds = client.bounds(
            for: CFRange(location: caretLocation, length: 1),
            in: element
        ).flatMap(appKitRect(from:)) {
            return NSPoint(x: nextBounds.minX, y: nextBounds.maxY)
        }

        guard caretLocation > 0,
              let previousBounds = client.bounds(
                  for: CFRange(location: caretLocation - 1, length: 1),
                  in: element
              ).flatMap(appKitRect(from:))
        else {
            return nil
        }
        return NSPoint(x: previousBounds.maxX, y: previousBounds.maxY)
    }

    func elementFrame(in element: AccessibilityElement) -> NSRect? {
        client.frame(of: element).flatMap(appKitRect(from:))
    }

    func diagnosticSummary(for elements: [AccessibilityElement]) -> String {
        var roleCounts: [String: Int] = [:]
        var selectedRangeCount = 0
        var markerRangeCount = 0
        var editableCount = 0
        var framedCount = 0

        for element in elements {
            let role = client.role(of: element) ?? "unknown"
            roleCounts[role, default: 0] += 1
            if client.hasAttribute(kAXSelectedTextRangeAttribute as String, in: element) {
                selectedRangeCount += 1
            }
            if client.hasAttribute("AXSelectedTextMarkerRange", in: element) {
                markerRangeCount += 1
            }
            if client.isEditable(of: element) {
                editableCount += 1
            }
            if client.frame(of: element) != nil {
                framedCount += 1
            }
        }

        let roles = roleCounts
            .sorted { lhs, rhs in
                lhs.key == rhs.key ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")
        return "candidates=\(elements.count); roles=[\(roles)]; selectedRange=\(selectedRangeCount); markerRange=\(markerRangeCount); editable=\(editableCount); framed=\(framedCount)"
    }

    private func clientChildren(of element: AccessibilityElement) -> [AccessibilityElement] {
        var children = [AccessibilityElement]()
        children.append(contentsOf: client.focusedElement(in: element).map { [$0] } ?? [])
        children.append(contentsOf: client.children(of: element))
        children.append(contentsOf: client.visibleChildren(of: element))
        children.append(contentsOf: client.contents(of: element))
        var unique: [AccessibilityElement] = []
        for child in children {
            append(child, to: &unique)
        }
        return unique
    }

    private func appendAncestors(to elements: inout [AccessibilityElement]) {
        var ancestorIndex = 0
        while ancestorIndex < elements.count, ancestorIndex < Self.ancestorLimit {
            let element = elements[ancestorIndex]
            appendDirectAncestors(of: element, to: &elements)
            ancestorIndex += 1
        }
    }

    private func appendDirectAncestors(
        of element: AccessibilityElement,
        to elements: inout [AccessibilityElement]
    ) {
        append(client.parent(of: element), to: &elements)
        append(client.editableAncestor(of: element), to: &elements)
        append(client.highestEditableAncestor(of: element), to: &elements)
    }

    private func traverseDescendants(
        of elements: inout [AccessibilityElement],
        limit: Int
    ) -> Bool {
        var descendantIndex = 0
        while descendantIndex < elements.count, elements.count < limit {
            let element = elements[descendantIndex]
            for child in clientChildren(of: element) {
                append(child, to: &elements, limit: limit)
                append(client.editableAncestor(of: child), to: &elements, limit: limit)
                if isPromisingTextInput(child) || elements.contains(where: isTextInput) {
                    return true
                }
                if elements.count >= limit { break }
            }
            descendantIndex += 1
        }
        return elements.contains(where: isTextInput)
    }

    private func append(_ element: AccessibilityElement?, to elements: inout [AccessibilityElement]) {
        guard let element else { return }
        append(element, to: &elements)
    }

    private func append(_ element: AccessibilityElement, to elements: inout [AccessibilityElement]) {
        guard !elements.contains(element) else { return }
        elements.append(element)
    }

    private func append(
        _ element: AccessibilityElement?,
        to elements: inout [AccessibilityElement],
        limit: Int
    ) {
        guard let element else { return }
        append(element, to: &elements, limit: limit)
    }

    private func append(
        _ element: AccessibilityElement,
        to elements: inout [AccessibilityElement],
        limit: Int
    ) {
        guard elements.count < limit, !elements.contains(element) else { return }
        elements.append(element)
    }

    private func appKitRect(from accessibilityRect: CGRect) -> NSRect? {
        let accessibilityCenter = CGPoint(x: accessibilityRect.midX, y: accessibilityRect.midY)

        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayBounds = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
            guard displayBounds.contains(accessibilityCenter) else { continue }

            return NSRect(
                x: screen.frame.minX + accessibilityRect.minX - displayBounds.minX,
                y: screen.frame.maxY - accessibilityRect.maxY + displayBounds.minY,
                width: accessibilityRect.width,
                height: accessibilityRect.height
            )
        }

        return nil
    }
}

private extension NSRect {
    var topCenter: NSPoint {
        NSPoint(x: midX, y: maxY)
    }
}
