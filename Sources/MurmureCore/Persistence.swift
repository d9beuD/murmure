import Foundation

public protocol PreferencesStoring: AnyObject {
    var preferences: AppPreferences { get }
    func save(_ preferences: AppPreferences)
    func reset()
}

public final class UserDefaultsPreferencesStore: PreferencesStoring {
    private let defaults: UserDefaults
    private let key = "murmure.preferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var preferences: AppPreferences {
        guard let data = defaults.data(forKey: key),
              let value = try? decoder.decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        // Future migrations have a single, explicit entry point.
        guard value.schemaVersion <= AppPreferences.currentSchemaVersion else { return AppPreferences() }
        return value
    }

    public func save(_ preferences: AppPreferences) {
        var value = preferences
        value.schemaVersion = AppPreferences.currentSchemaVersion
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    public func reset() {
        defaults.removeObject(forKey: key)
    }
}
