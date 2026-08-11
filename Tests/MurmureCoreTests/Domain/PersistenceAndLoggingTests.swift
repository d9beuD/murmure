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

    func testSafeLogMessages() {
        struct SensitiveError: LocalizedError {
            var errorDescription: String? { "secret transcript" }
        }

        XCTAssertEqual(safeLogMessage(for: StubError.failure), "Safe failure")
        XCTAssertEqual(safeLogMessage(for: SensitiveError()), "Operation failed with no exportable details.")
        XCTAssertFalse(safeLogMessage(for: SensitiveError()).contains("secret"))
    }

}
