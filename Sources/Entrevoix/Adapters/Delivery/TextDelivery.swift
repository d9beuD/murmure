import AppKit
import EntrevoixCore

@MainActor
final class TextDelivery: TextDelivering {
    private let resolver: FocusedTextElementResolver
    private let pasteEventPoster: any PasteEventPosting

    init(
        resolver: FocusedTextElementResolver = .shared,
        pasteEventPoster: any PasteEventPosting = SystemPasteEventPoster()
    ) {
        self.resolver = resolver
        self.pasteEventPoster = pasteEventPoster
    }

    func copy(_ text: String) {
        let deliverableText = prepareForDelivery(text)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deliverableText, forType: .string)
    }

    func copyAndPaste(_ text: String) {
        copy(text)
        _ = pasteEventPoster.postPaste()
    }

    func deliver(_ text: String, mode: OutputMode) -> TextDeliveryResult {
        guard mode == .paste else {
            copy(text)
            return .copied
        }

        guard resolver.client.isTrusted() else {
            copy(text)
            return .fallbackCopied(reason: "Accessibility permission missing")
        }

        let focusedTextElement = resolver.resolve()
        if let focusedTextElement, focusedTextElement.isSecure {
            copy(text)
            return .secureFieldCopied
        }

        if let focusedTextElement,
           focusedTextElement.isEditable,
           !focusedTextElement.isWebEditor,
           resolver.client.replaceSelectedText(prepareForDelivery(text), in: focusedTextElement.element) {
            return .inserted
        }

        copy(text)
        guard pasteEventPoster.postPaste() else {
            return .fallbackCopied(reason: "paste event could not be posted")
        }
        return .inserted
    }

    private func prepareForDelivery(_ text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return "" }
        return "\(trimmedText) "
    }
}
