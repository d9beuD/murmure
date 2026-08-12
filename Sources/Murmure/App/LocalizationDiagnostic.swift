import Darwin
import Foundation
import MurmureCore

enum LocalizationDiagnostic {
    private static let command = "--verify-localization"

    static func runIfRequested(arguments: [String] = CommandLine.arguments) -> Bool {
        guard let commandIndex = arguments.firstIndex(of: command) else { return false }

        let mode = commandIndex + 1 < arguments.count ? arguments[commandIndex + 1] : ""
        let language: InterfaceLanguage
        switch mode {
        case "automatic": language = .automatic
        case "english": language = .english
        case "french": language = .french
        default:
            fputs("Usage: Murmure --verify-localization <automatic|english|french>\n", stderr)
            exit(64)
        }

        let locale = MurmureLocalization.locale(for: language)
        let values = [
            ("locale", locale.identifier),
            ("onboarding.welcome.title", MurmureLocalization.text(
                "onboarding.welcome.title",
                defaultValue: "Welcome to Murmure",
                locale: locale
            )),
            ("menu.settings", MurmureLocalization.text(
                "menu.settings",
                defaultValue: "Settings",
                locale: locale
            )),
            ("action.next", MurmureLocalization.text(
                "action.next",
                defaultValue: "Next",
                locale: locale
            ))
        ]
        for (key, value) in values {
            print("\(key)=\(value)")
        }
        return true
    }
}
