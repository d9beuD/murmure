import Foundation
import KeyboardShortcuts

@MainActor
enum KeyboardShortcutsDiagnostic {
    private static let command = "--verify-keyboard-shortcuts"

    static func runIfRequested(arguments: [String] = CommandLine.arguments) -> Bool {
        guard arguments.contains(command) else { return false }

        _ = KeyboardShortcuts.RecorderCocoa(for: .cancel)
        print("keyboardShortcuts.resourceBundle=available")
        return true
    }
}
