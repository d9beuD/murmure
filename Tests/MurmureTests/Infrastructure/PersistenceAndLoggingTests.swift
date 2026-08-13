import Foundation
import XCTest
import MurmureCore
@testable import Murmure

final class PersistenceAndLoggingTests: XCTestCase {
    func testUserDefaultsStoreSaveResetAndInvalidData() {
        withStore { store, defaults in
            guard case .loaded(let initial) = store.load() else {
                return XCTFail("Expected default preferences")
            }
            XCTAssertEqual(initial, AppPreferences())

            var preferences = AppPreferences(schemaVersion: 1)
            preferences.sttLanguage = .french
            store.save(preferences)
            guard case .loaded(let loaded) = store.load() else {
                return XCTFail("Expected valid preferences")
            }
            XCTAssertEqual(loaded.sttLanguage, .french)
            XCTAssertEqual(loaded.schemaVersion, AppPreferences.currentSchemaVersion)

            defaults.set(Data("not-json".utf8), forKey: "murmure.preferences")
            guard case .recovered(let recovered) = store.load() else {
                return XCTFail("Expected preferences recovery")
            }
            XCTAssertEqual(recovered, AppPreferences())
            XCTAssertTrue(FileManager.default.fileExists(atPath: recoveryURL.path))
            XCTAssertEqual(try? Data(contentsOf: recoveryURL), Data("not-json".utf8))

            store.reset()
            XCTAssertNil(defaults.data(forKey: "murmure.preferences"))
        }
    }

    func testFuturePreferencesAreRejectedWithoutOverwrite() throws {
        try withStore { store, defaults in
            var preferences = AppPreferences(schemaVersion: AppPreferences.currentSchemaVersion + 1)
            preferences.sttLanguage = .automatic
            defaults.set(try JSONEncoder().encode(preferences), forKey: "murmure.preferences")

            guard case .incompatible(let schemaVersion) = store.load() else {
                return XCTFail("Expected future schema to be rejected")
            }
            XCTAssertEqual(schemaVersion, AppPreferences.currentSchemaVersion + 1)
            XCTAssertEqual(defaults.data(forKey: "murmure.preferences"), try JSONEncoder().encode(preferences))
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

    private var recoveryURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("murmure-recovery-\(name).json")
    }

    private func withStore(_ body: (UserDefaultsPreferencesStore, UserDefaults) throws -> Void) rethrows {
        let suite = "MurmureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: recoveryURL)
        }
        try body(UserDefaultsPreferencesStore(defaults: defaults, recoveryURL: recoveryURL), defaults)
    }
}
