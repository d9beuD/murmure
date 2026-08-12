import Foundation
import MurmureCore

enum MurmureLocalization {
    static func locale(
        for language: InterfaceLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Locale {
        switch language {
        case .automatic:
            for preferredLanguage in preferredLanguages {
                let languageCode = Locale(identifier: preferredLanguage)
                    .language.languageCode?.identifier
                if languageCode == "fr" {
                    return Locale(identifier: "fr-FR")
                }
                if languageCode == "en" {
                    return Locale(identifier: "en")
                }
            }
            return Locale(identifier: "en")
        case .english:
            return Locale(identifier: "en")
        case .french:
            return Locale(identifier: "fr-FR")
        }
    }

    static func text(
        _ key: String,
        defaultValue: String,
        locale: Locale
    ) -> String {
        let localizedBundle = bundle(for: locale)
        return localizedBundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    private static func bundle(for locale: Locale) -> Bundle {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if let path = Bundle.module.path(forResource: identifier, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            return localizedBundle
        }
        if let languageCode = locale.language.languageCode?.identifier,
           let path = Bundle.module.path(forResource: languageCode, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            return localizedBundle
        }
        return Bundle.module
    }

    static func characterCount(_ count: Int, locale: Locale) -> String {
        let format = text(
            "connection_test.received_characters",
            defaultValue: "Connection verified: received %lld characters.",
            locale: locale
        )
        return String(format: format, locale: locale, arguments: [count])
    }

    static func onboardingStep(_ step: Int, total: Int, locale: Locale) -> String {
        let format = text("onboarding.step", defaultValue: "Step %lld of %lld", locale: locale)
        return String(format: format, locale: locale, arguments: [step, total])
    }

    static func connectionStatus(_ status: String, locale: Locale) -> String {
        let format = text("accessibility.connection_status", defaultValue: "Connection test status: %@", locale: locale)
        return String(format: format, locale: locale, arguments: [status])
    }

    static func permissionStatus(name: String, status: String, locale: Locale) -> String {
        let format = text("accessibility.permission_status", defaultValue: "%@ status: %@", locale: locale)
        return String(format: format, locale: locale, arguments: [name, status])
    }

    static func defaultCleanupPrompt(locale: Locale) -> String {
        text(
            "cleanup.default_prompt",
            defaultValue: "Clean up the transcript without changing its meaning. Correct punctuation, mistakes, and hesitations. Return only the final text.",
            locale: locale
        )
    }

    static func sourceCatalogData() -> Data? {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings") else { return nil }
        return try? Data(contentsOf: url)
    }
}

extension InterfaceLanguage {
    func title(locale: Locale) -> String {
        switch self {
        case .automatic:
            MurmureLocalization.text("language.automatic", defaultValue: "Automatic", locale: locale)
        case .english:
            "English"
        case .french:
            "Français"
        }
    }
}
