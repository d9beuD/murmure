import AppKit
import ApplicationServices
import MurmureCore
import SwiftUI

@MainActor
protocol ListeningIndicatorPresenting: AnyObject {
    func show(label: String)
    func hide()
}

@MainActor
final class ListeningIndicatorController: ListeningIndicatorPresenting {
    private static let panelSize = NSSize(width: 128, height: 40)
    private static let anchorSpacing: CGFloat = 8

    private let positionProvider: ListeningIndicatorPositionProvider
    private let logger: any LogWriting
    private var panel: NSPanel?
    private var hostingView: NSHostingView<ListeningIndicatorView>?
    private var positionTrackingTask: Task<Void, Never>?
    private var loggedAnchorSource: ListeningIndicatorAnchor.Source?
    private var lastAnchor: ListeningIndicatorAnchor?
    private var pendingInitialAnchor: ListeningIndicatorAnchor?
    private var unresolvedInitialSampleCount = 0
    private var isPanelVisible = false

    init(
        positionProvider: ListeningIndicatorPositionProvider = ListeningIndicatorPositionProvider(),
        logger: any LogWriting
    ) {
        self.positionProvider = positionProvider
        self.logger = logger
    }

    func show(label: String) {
        let panel = makePanelIfNeeded(label: label)
        hostingView?.rootView = ListeningIndicatorView(label: label)
        loggedAnchorSource = nil
        lastAnchor = nil
        pendingInitialAnchor = nil
        unresolvedInitialSampleCount = 0
        isPanelVisible = false
        panel.orderOut(nil)
        updatePosition()

        positionTrackingTask?.cancel()
        positionTrackingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
                self?.updatePosition()
            }
        }
    }

    func hide() {
        positionTrackingTask?.cancel()
        positionTrackingTask = nil
        lastAnchor = nil
        pendingInitialAnchor = nil
        unresolvedInitialSampleCount = 0
        isPanelVisible = false
        panel?.orderOut(nil)
    }

    private func makePanelIfNeeded(label: String) -> NSPanel {
        if let panel {
            return panel
        }

        let panel = ListeningIndicatorPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]

        let hostingView = NSHostingView(rootView: ListeningIndicatorView(label: label))
        hostingView.frame = NSRect(origin: .zero, size: Self.panelSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.panel = panel
        self.hostingView = hostingView
        return panel
    }

    private func updatePosition() {
        guard let panel else { return }
        var anchor = positionProvider.anchor()
        if anchor.source.isFallback, isPanelVisible, let lastAnchor {
            anchor = lastAnchor
        } else if !anchor.source.isFallback {
            lastAnchor = anchor
        }
        if loggedAnchorSource != anchor.source {
            logger.log("Listening indicator anchor: \(anchor.source.logDescription)")
            if let diagnostic = anchor.diagnostic {
                logger.log("Listening indicator AX diagnostic: \(diagnostic)")
            }
            loggedAnchorSource = anchor.source
        }
        guard isPanelVisible || initialAnchorIsReady(anchor) else { return }
        let visibleFrame = screen(containing: anchor.point)?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(origin: .zero, size: Self.panelSize)

        let proposedX = anchor.point.x - (Self.panelSize.width / 2)
        let aboveY = anchor.point.y + Self.anchorSpacing
        let belowY = anchor.point.y - Self.anchorSpacing - Self.panelSize.height
        let proposedY = aboveY + Self.panelSize.height <= visibleFrame.maxY ? aboveY : belowY
        let maximumX = max(visibleFrame.minX, visibleFrame.maxX - Self.panelSize.width)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - Self.panelSize.height)
        let origin = NSPoint(
            x: min(max(proposedX, visibleFrame.minX), maximumX),
            y: min(max(proposedY, visibleFrame.minY), maximumY)
        )

        panel.setFrameOrigin(origin)
        if !isPanelVisible {
            isPanelVisible = true
            panel.orderFrontRegardless()
        }
    }

    private func initialAnchorIsReady(_ anchor: ListeningIndicatorAnchor) -> Bool {
        switch anchor.source {
        case .directCaret, .textMarkerCaret, .adjacentCharacter, .accessibilityPermissionMissing:
            return true
        case .focusedTextElement:
            defer { pendingInitialAnchor = anchor }
            guard let pendingInitialAnchor,
                  pendingInitialAnchor.source == anchor.source
            else {
                return false
            }
            return hypot(
                pendingInitialAnchor.point.x - anchor.point.x,
                pendingInitialAnchor.point.y - anchor.point.y
            ) <= 4
        case .focusedInputUnavailable:
            // Give a lazily-built web accessibility tree a few polling cycles
            // before falling back to the pointer in an unsupported control.
            unresolvedInitialSampleCount += 1
            return unresolvedInitialSampleCount >= 3
        }
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }
}

@MainActor
struct ListeningIndicatorPositionProvider {
    func anchor() -> ListeningIndicatorAnchor {
        guard AXIsProcessTrusted() else {
            return ListeningIndicatorAnchor(
                point: NSEvent.mouseLocation,
                source: .accessibilityPermissionMissing
            )
        }

        let elements = focusedElementCandidates()
        for element in elements {
            if let point = directCaretPoint(in: element) {
                return ListeningIndicatorAnchor(point: point, source: .directCaret)
            }
            if let point = textMarkerCaretPoint(in: element) {
                return ListeningIndicatorAnchor(point: point, source: .textMarkerCaret)
            }
            if let point = adjacentCharacterCaretPoint(in: element) {
                return ListeningIndicatorAnchor(point: point, source: .adjacentCharacter)
            }
        }

        for element in elements where isTextInput(element) {
            if let frame = elementFrame(element), let appKitFrame = appKitRect(from: frame) {
                let leadingInset = min(16, appKitFrame.width / 2)
                return ListeningIndicatorAnchor(
                    point: NSPoint(x: appKitFrame.minX + leadingInset, y: appKitFrame.maxY),
                    source: .focusedTextElement
                )
            }
        }

        return ListeningIndicatorAnchor(
            point: NSEvent.mouseLocation,
            source: .focusedInputUnavailable,
            diagnostic: diagnosticSummary(for: elements)
        )
    }

    private func directCaretPoint(in element: AXUIElement) -> NSPoint? {
        guard let selectedRange = selectedTextRange(in: element) else { return nil }
        let caretRange = CFRange(
            location: selectedRange.location + selectedRange.length,
            length: 0
        )
        return bounds(for: caretRange, in: element)
            .flatMap(appKitRect(from:))?
            .topCenter
    }

    private func textMarkerCaretPoint(in element: AXUIElement) -> NSPoint? {
        let selectedTextMarkerRangeAttribute = "AXSelectedTextMarkerRange" as CFString
        let boundsForTextMarkerRangeAttribute = "AXBoundsForTextMarkerRange" as CFString

        var markerRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            selectedTextMarkerRangeAttribute,
            &markerRange
        ) == .success,
        let markerRange
        else {
            return nil
        }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            boundsForTextMarkerRangeAttribute,
            markerRange,
            &boundsValue
        ) == .success,
        let boundsValue,
        let bounds = cgRect(from: boundsValue),
        let appKitBounds = appKitRect(from: bounds)
        else {
            return nil
        }
        return appKitBounds.topCenter
    }

    private func adjacentCharacterCaretPoint(in element: AXUIElement) -> NSPoint? {
        guard let selectedRange = selectedTextRange(in: element) else { return nil }
        let caretLocation = selectedRange.location + selectedRange.length

        if let nextBounds = bounds(
            for: CFRange(location: caretLocation, length: 1),
            in: element
        ).flatMap(appKitRect(from:)) {
            return NSPoint(x: nextBounds.minX, y: nextBounds.maxY)
        }

        guard caretLocation > 0,
              let previousBounds = bounds(
                  for: CFRange(location: caretLocation - 1, length: 1),
                  in: element
              ).flatMap(appKitRect(from:))
        else {
            return nil
        }
        return NSPoint(x: previousBounds.maxX, y: previousBounds.maxY)
    }

    private func selectedTextRange(in element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
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

    private func bounds(for range: CFRange, in element: AXUIElement) -> CGRect? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
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

    private func focusedElementCandidates() -> [AXUIElement] {
        let systemWideElement = AXUIElementCreateSystemWide()
        var candidates: [AXUIElement] = []

        if let focusedElement = uiElementAttribute(
            kAXFocusedUIElementAttribute as CFString,
            of: systemWideElement
        ) {
            append(focusedElement, to: &candidates)
        }

        var applications: [AXUIElement] = []
        if let focusedApplication = uiElementAttribute(
            kAXFocusedApplicationAttribute as CFString,
            of: systemWideElement
        ) {
            append(focusedApplication, to: &applications)
        }
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            append(
                AXUIElementCreateApplication(frontmostApplication.processIdentifier),
                to: &applications
            )
        }

        for application in applications {
            AXUIElementSetMessagingTimeout(application, 0.2)
            enableWebAccessibility(in: application)
            append(application, to: &candidates)
            if let focusedElement = uiElementAttribute(
                kAXFocusedUIElementAttribute as CFString,
                of: application
            ) {
                append(focusedElement, to: &candidates)
            }
            if let focusedWindow = uiElementAttribute(
                kAXFocusedWindowAttribute as CFString,
                of: application
            ) {
                enableWebAccessibility(in: focusedWindow)
                append(focusedWindow, to: &candidates)
                if let focusedElement = uiElementAttribute(
                    kAXFocusedUIElementAttribute as CFString,
                    of: focusedWindow
                ) {
                    append(focusedElement, to: &candidates)
                }
            }
        }

        var index = 0
        while index < candidates.count, index < 6 {
            if let parent = uiElementAttribute(
                kAXParentAttribute as CFString,
                of: candidates[index]
            ) {
                append(parent, to: &candidates)
            }
            index += 1
        }

        if candidates.contains(where: isPromisingTextInput) {
            return candidates
        }

        // Breadth-first traversal prevents a large sidebar or toolbar subtree
        // from consuming the whole budget before the web editor is visited.
        var descendantIndex = 0
        let descendantLimit = 384
        while descendantIndex < candidates.count, candidates.count < descendantLimit {
            let element = candidates[descendantIndex]
            for attribute in [
                kAXFocusedUIElementAttribute as CFString,
                kAXChildrenAttribute as CFString,
                kAXVisibleChildrenAttribute as CFString,
                kAXContentsAttribute as CFString
            ] {
                for child in uiElementAttributes(attribute, of: element) {
                    append(child, to: &candidates)
                    if isPromisingTextInput(child) {
                        return candidates
                    }
                    if candidates.count >= descendantLimit { break }
                }
                if candidates.count >= descendantLimit { break }
            }
            descendantIndex += 1
        }
        return candidates
    }

    private func isPromisingTextInput(_ element: AXUIElement) -> Bool {
        if hasAttribute(kAXSelectedTextRangeAttribute as CFString, in: element)
            || hasAttribute("AXSelectedTextMarkerRange" as CFString, in: element)
            || booleanAttribute("AXEditable" as CFString, in: element) {
            return true
        }
        guard let role = stringAttribute(kAXRoleAttribute as CFString, in: element) else {
            return false
        }
        return [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            "AXSearchField",
            kAXComboBoxRole as String
        ].contains(role)
    }

    private func enableWebAccessibility(in element: AXUIElement) {
        // Chromium/Electron builds their detailed accessibility tree lazily.
        // These are the attributes documented for third-party assistive tools
        // on Electron and Chromium respectively. Failures are expected for
        // native applications and can safely be ignored.
        AXUIElementSetAttributeValue(
            element,
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )
        AXUIElementSetAttributeValue(
            element,
            "AXEnhancedUserInterface" as CFString,
            kCFBooleanTrue
        )
    }

    private func append(_ element: AXUIElement, to elements: inout [AXUIElement]) {
        guard !elements.contains(where: { CFEqual($0, element) }) else { return }
        elements.append(element)
    }

    private func uiElementAttribute(_ attribute: CFString, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func uiElementAttributes(_ attribute: CFString, of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value
        else {
            return []
        }

        if CFGetTypeID(value) == AXUIElementGetTypeID() {
            return [unsafeDowncast(value, to: AXUIElement.self)]
        }
        guard CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
        let values = unsafeDowncast(value, to: CFArray.self) as [AnyObject]
        return values.compactMap { candidate in
            guard CFGetTypeID(candidate) == AXUIElementGetTypeID() else { return nil }
            return unsafeDowncast(candidate, to: AXUIElement.self)
        }
    }

    private func isTextInput(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &value
        ) == .success,
           let role = value as? String,
           [
               kAXTextFieldRole as String,
               kAXTextAreaRole as String,
               "AXSearchField",
               kAXComboBoxRole as String
           ].contains(role) {
            return true
        }

        // Chromium/Electron content-editable controls can be exposed as an
        // AXGroup rather than a text role. Their editable/selection attributes
        // are still sufficient to anchor the indicator to the composer when
        // the browser withholds the exact caret rectangle.
        if booleanAttribute("AXEditable" as CFString, in: element) {
            return true
        }
        guard let role = value as? String else { return false }
        return ["AXGroup", "AXGenericElement"].contains(role)
            && hasAttribute(kAXSelectedTextRangeAttribute as CFString, in: element)
    }

    private func hasAttribute(_ attribute: CFString, in element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute, &value) == .success
    }

    private func booleanAttribute(_ attribute: CFString, in element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value,
              CFGetTypeID(value) == CFBooleanGetTypeID()
        else {
            return false
        }
        return CFBooleanGetValue(unsafeDowncast(value, to: CFBoolean.self))
    }

    private func diagnosticSummary(for elements: [AXUIElement]) -> String {
        var roleCounts: [String: Int] = [:]
        var selectedRangeCount = 0
        var markerRangeCount = 0
        var editableCount = 0
        var framedCount = 0

        for element in elements {
            let role = stringAttribute(kAXRoleAttribute as CFString, in: element) ?? "unknown"
            roleCounts[role, default: 0] += 1
            if hasAttribute(kAXSelectedTextRangeAttribute as CFString, in: element) {
                selectedRangeCount += 1
            }
            if hasAttribute("AXSelectedTextMarkerRange" as CFString, in: element) {
                markerRangeCount += 1
            }
            if booleanAttribute("AXEditable" as CFString, in: element) {
                editableCount += 1
            }
            if elementFrame(element) != nil {
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

    private func stringAttribute(_ attribute: CFString, in element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func elementFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            element,
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

struct ListeningIndicatorAnchor {
    enum Source: Equatable {
        case directCaret
        case textMarkerCaret
        case adjacentCharacter
        case focusedTextElement
        case accessibilityPermissionMissing
        case focusedInputUnavailable

        var isFallback: Bool {
            switch self {
            case .accessibilityPermissionMissing, .focusedInputUnavailable: true
            default: false
            }
        }

        var logDescription: String {
            switch self {
            case .directCaret: "text caret"
            case .textMarkerCaret: "browser text caret"
            case .adjacentCharacter: "adjacent character"
            case .focusedTextElement: "focused text field"
            case .accessibilityPermissionMissing: "Accessibility permission missing"
            case .focusedInputUnavailable: "focused input unavailable"
            }
        }
    }

    let point: NSPoint
    let source: Source
    let diagnostic: String?

    init(point: NSPoint, source: Source, diagnostic: String? = nil) {
        self.point = point
        self.source = source
        self.diagnostic = diagnostic
    }
}

private final class ListeningIndicatorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct ListeningIndicatorView: View {
    let label: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(nsColor: .systemRed).opacity(0.18))
                    .frame(width: 24, height: 24)
                    .scaleEffect(isPulsing ? 1.12 : 0.82)

                Image(systemName: "mic.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color(nsColor: .systemRed))
            }

            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(width: 128, height: 40)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .onAppear {
            updateAnimation()
        }
        .onChange(of: reduceMotion) {
            updateAnimation()
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: isPulsing
        )
    }

    private func updateAnimation() {
        isPulsing = !reduceMotion
    }
}

private extension NSRect {
    var topCenter: NSPoint {
        NSPoint(x: midX, y: maxY)
    }
}
