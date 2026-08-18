import AppKit
import EntrevoixCore

@MainActor
protocol ProviderAlertPresenting: AnyObject {
    func presentUnavailable(capability: ProviderCapability, reason: ProviderUnavailabilityReason)
}

@MainActor
final class QueuedProviderAlertPresenter: ProviderAlertPresenting {
    private var queue: [(ProviderCapability, ProviderUnavailabilityReason)] = []
    private var isPresenting = false

    func presentUnavailable(capability: ProviderCapability, reason: ProviderUnavailabilityReason) {
        queue.append((capability, reason))
        presentNextIfNeeded()
    }

    private func presentNextIfNeeded() {
        guard !isPresenting, let item = queue.first else { return }
        isPresenting = true
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = item.0 == .stt ? "Apple Speech is unavailable" : "Apple text cleanup is unavailable"
        alert.informativeText = "The selected local Apple capability is not ready on this Mac. No dictation content is included in this alert."
        alert.addButton(withTitle: "OK")
        let complete = { [weak self] in
            guard let self else { return }
            self.queue.removeFirst()
            self.isPresenting = false
            self.presentNextIfNeeded()
        }
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            alert.beginSheetModal(for: window) { _ in complete() }
        } else {
            alert.runModal()
            complete()
        }
    }
}

@MainActor
private final class NoOpProviderAlertPresenter: ProviderAlertPresenting {
    func presentUnavailable(capability: ProviderCapability, reason: ProviderUnavailabilityReason) {}
}

@MainActor
func makeNoOpProviderAlertPresenter() -> any ProviderAlertPresenting { NoOpProviderAlertPresenter() }
