import Foundation
import MurmureCore

final class UserDefaultsPreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private let key = "murmure.preferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferences: AppPreferences {
        guard let data = defaults.data(forKey: key),
              let value = try? decoder.decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        guard value.schemaVersion <= AppPreferences.currentSchemaVersion else { return AppPreferences() }
        return value
    }

    func save(_ preferences: AppPreferences) {
        var value = preferences
        value.schemaVersion = AppPreferences.currentSchemaVersion
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
