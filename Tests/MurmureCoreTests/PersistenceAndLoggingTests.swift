import Foundation
import XCTest
@testable import MurmureCore

final class PersistenceAndLoggingTests: XCTestCase {
    func testPreferencesDefaultsAndRoundTrip() throws {
        var preferences = AppPreferences()
        XCTAssertEqual(preferences.schemaVersion, AppPreferences.currentSchemaVersion)
        XCTAssertFalse(preferences.hasCompletedOnboarding)
        XCTAssertTrue(preferences.cleanupEnabled)

        preferences.sttLanguage = "fr"
        preferences.sttPrompt = "names"
        preferences.triggerMode = .toggle
        preferences.cleanupFormat = .chatCompletions
        preferences.cleanupFailurePolicy = .stop
        preferences.outputMode = .paste
        preferences.launchAtLogin = true
        preferences.playFeedbackSounds = false
        preferences.hasCompletedOnboarding = true

        let decoded = try JSONDecoder().decode(
            AppPreferences.self,
            from: JSONEncoder().encode(preferences)
        )
        XCTAssertEqual(decoded, preferences)
    }

    func testMissingFieldsUseCurrentDefaults() throws {
        let data = Data("{\"schemaVersion\":4}".utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(preferences.stt, .openAITranscription)
        XCTAssertEqual(preferences.cleanupProvider, .openAIResponses)
        XCTAssertEqual(preferences.cleanupPrompt, AppPreferences.defaultCleanupPrompt)
        XCTAssertFalse(preferences.hasCompletedOnboarding)
    }

    func testLegacyPreferencesSkipOnboarding() throws {
        let data = Data("{\"schemaVersion\":3}".utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
        XCTAssertTrue(preferences.hasCompletedOnboarding)
    }

    func testUserDefaultsStoreSaveResetAndInvalidData() {
        withStore { store, defaults in
            XCTAssertEqual(store.preferences, AppPreferences())

            var preferences = AppPreferences(schemaVersion: 1)
            preferences.sttLanguage = "fr"
            store.save(preferences)
            XCTAssertEqual(store.preferences.sttLanguage, "fr")
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
            preferences.sttLanguage = "future"
            defaults.set(try JSONEncoder().encode(preferences), forKey: "murmure.preferences")

            XCTAssertEqual(store.preferences, AppPreferences())
        }
    }

    func testSafeLogMessages() {
        struct SensitiveError: LocalizedError {
            var errorDescription: String? { "secret transcript" }
        }

        XCTAssertEqual(safeLogMessage(for: StubError.failure), "Safe failure")
        XCTAssertEqual(safeLogMessage(for: SensitiveError()), "Operation failed with no exportable details.")
        XCTAssertFalse(safeLogMessage(for: SensitiveError()).contains("secret"))
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
        let suite = "MurmureCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(UserDefaultsPreferencesStore(defaults: defaults), defaults)
    }
}
