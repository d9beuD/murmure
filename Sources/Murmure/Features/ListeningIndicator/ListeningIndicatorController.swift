import AppKit
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
    let resolver: FocusedTextElementResolver

    init(resolver: FocusedTextElementResolver = .shared) {
        self.resolver = resolver
    }

    func anchor() -> ListeningIndicatorAnchor {
        guard resolver.client.isTrusted() else {
            return ListeningIndicatorAnchor(
                point: NSEvent.mouseLocation,
                source: .accessibilityPermissionMissing
            )
        }

        let elements = resolver.focusedElementCandidates()
        for element in elements {
            if let point = resolver.directCaretPoint(in: element) {
                return ListeningIndicatorAnchor(point: point, source: .directCaret)
            }
            if let point = resolver.textMarkerCaretPoint(in: element) {
                return ListeningIndicatorAnchor(point: point, source: .textMarkerCaret)
            }
            if let point = resolver.adjacentCharacterCaretPoint(in: element) {
                return ListeningIndicatorAnchor(point: point, source: .adjacentCharacter)
            }
        }

        for element in elements where resolver.isTextInput(element) {
            if let frame = resolver.elementFrame(in: element) {
                let leadingInset = min(16, frame.width / 2)
                return ListeningIndicatorAnchor(
                    point: NSPoint(x: frame.minX + leadingInset, y: frame.maxY),
                    source: .focusedTextElement
                )
            }
        }

        return ListeningIndicatorAnchor(
            point: NSEvent.mouseLocation,
            source: .focusedInputUnavailable,
            diagnostic: resolver.diagnosticSummary(for: elements)
        )
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
