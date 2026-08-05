import KeyboardShortcuts

@preconcurrency import MurmureCore

@MainActor
extension KeyboardShortcuts.Name {
    static let dictation = Self("dictation")
}

@MainActor
final class HotkeyService {
    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    init() {
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
    }
}
