import Foundation

enum LegacyMurmureMigration {
    static let legacyBundleIdentifier = "com.d9beuD.Murmure"
    static let currentBundleIdentifier = "com.d9beuD.Entrevoix"
    static let legacyPreferencesKey = "murmure.preferences"
    static let currentPreferencesKey = "entrevoix.preferences"
    static let completionKey = "entrevoix.migration.murmure.completed"
    static let legacyKeychainService = "com.d9beuD.Murmure"
    static let currentKeychainService = "com.d9beuD.Entrevoix"

    static func run(
        defaults: UserDefaults = .standard,
        legacyDomain: [String: Any]? = nil
    ) {
        guard defaults.object(forKey: completionKey) == nil else { return }

        let sourceDomain = legacyDomain
            ?? UserDefaults.standard.persistentDomain(forName: legacyBundleIdentifier)
            ?? [:]

        for (key, value) in sourceDomain {
            let destinationKey = key == legacyPreferencesKey ? currentPreferencesKey : key
            guard defaults.object(forKey: destinationKey) == nil else { continue }
            defaults.set(value, forKey: destinationKey)
        }

        defaults.set(true, forKey: completionKey)
    }
}
