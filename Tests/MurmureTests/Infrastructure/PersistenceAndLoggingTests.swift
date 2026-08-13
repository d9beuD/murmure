import Foundation
import XCTest
import MurmureCore
@testable import Murmure

final class PersistenceAndLoggingTests: XCTestCase {
    func testUserDefaultsStoreSaveResetAndInvalidData() {
        withStore { store, defaults in
            XCTAssertEqual(store.preferences, AppPreferences())

            var preferences = AppPreferences(schemaVersion: 1)
            preferences.sttLanguage = .french
            store.save(preferences)
            XCTAssertEqual(store.preferences.sttLanguage, .french)
            XCTAssertEqual(store.preferences.schemaVersion, AppPreferences.currentSchemaVersion)

            defaults.set(Data("not-json".utf8), forKey: "murmure.preferences")
            XCTAssertEqual(store.preferences, AppPreferences())

            store.reset()
            XCTAssertNil(defaults.data(forKey: "murmure.preferences"))
        }
    }

    func testFuturePreferencesFallBackToDefaults() throws {
        try withStore { store, defaults in
            var preferences = AppPreferences(schemaVersion: AppPreferences.currentSchemaVersion + 1)
            preferences.sttLanguage = .automatic
            defaults.set(try JSONEncoder().encode(preferences), forKey: "murmure.preferences")

            XCTAssertEqual(store.preferences, AppPreferences())
        }
    }

    @MainActor
    func testLogStorePreservesOrderAndClears() {
        let store = AppLogStore()
        store.log("first")
        store.log("second")

        XCTAssertEqual(store.entries.map(\.message), ["first", "second"])
        XCTAssertNotEqual(store.entries[0].id, store.entries[1].id)
        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
    }

    private func withStore(_ body: (UserDefaultsPreferencesStore, UserDefaults) throws -> Void) rethrows {
        let suite = "MurmureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(UserDefaultsPreferencesStore(defaults: defaults), defaults)
    }
}
