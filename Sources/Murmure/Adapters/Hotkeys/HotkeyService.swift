import KeyboardShortcuts

@preconcurrency import MurmureCore

@MainActor
extension KeyboardShortcuts.Name {
    static let dictation = Self("dictation")
    static let cancel = Self("cancel", default: .init(.escape))
}

@MainActor
final class HotkeyService: HotkeyHandling {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?
    var onEscape: (() -> Void)?
    private var isInstalled = false

    init() {
        // RegisterEventHotKey can fail silently when called while SwiftUI is still
        // constructing the application, before the Carbon event dispatcher exists.
        // Defer installation until the main run loop has started.
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.install()
        }
    }

    private func install() {
        guard !isInstalled else { return }
        isInstalled = true

        KeyboardShortcuts.onKeyDown(for: .dictation) { [weak self] in
            Task { @MainActor in
                self?.onKeyDown?()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .dictation) { [weak self] in
            Task { @MainActor in
                self?.onKeyUp?()
            }
        }
        KeyboardShortcuts.onKeyDown(for: .cancel) { [weak self] in
            Task { @MainActor in
                self?.onEscape?()
            }
        }
    }

}
