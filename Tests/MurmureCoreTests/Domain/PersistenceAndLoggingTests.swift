import Foundation
import XCTest
@testable import MurmureCore

final class PersistenceAndLoggingTests: XCTestCase {
    func testPreferencesDefaultsAndRoundTrip() throws {
        var preferences = AppPreferences(dictationDictionary: ["  Symfony ", "CapRover", "Symfony", "  "])
        XCTAssertEqual(preferences.schemaVersion, AppPreferences.currentSchemaVersion)
        XCTAssertFalse(preferences.hasCompletedOnboarding)
        XCTAssertTrue(preferences.cleanupEnabled)
        XCTAssertEqual(preferences.sttLanguage, .automatic)
        XCTAssertEqual(preferences.sttFavoriteLanguages, [.french, .english])
        XCTAssertEqual(preferences.dictationDictionary, ["Symfony", "CapRover"])
        XCTAssertEqual(preferences.dictationDictionaryPrompt, "Symfony, CapRover")

        preferences.sttLanguage = .french
        preferences.dictationDictionary = ["Symfony", "CapRover"]
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

    func testPromptLibraryRoundTripAndEmptyLibrary() throws {
        let first = CleanupPrompt(name: "Writing", systemImageName: "quote.bubble", instructions: "Improve writing.")
        let second = CleanupPrompt(name: "Code", systemImageName: "terminal", instructions: "Keep code exact.")
        var preferences = AppPreferences(cleanupPrompts: [first, second], activeCleanupPromptID: second.id)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(decoded.cleanupPrompts, [first, second])
        XCTAssertEqual(decoded.activeCleanupPromptID, second.id)

        preferences.cleanupPrompts = []
        preferences.activeCleanupPromptID = nil
        let empty = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertTrue(empty.cleanupPrompts.isEmpty)
        XCTAssertNil(empty.activeCleanupPromptID)
    }

    func testMissingFieldsUseCurrentDefaults() throws {
        let data = Data("{\"schemaVersion\":4}".utf8)
        let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(preferences.stt, .openAITranscription)
        XCTAssertEqual(preferences.cleanupProvider, .openAIResponses)
        XCTAssertEqual(preferences.cleanupPrompt, AppPreferences.defaultCleanupPrompt)
        XCTAssertFalse(preferences.hasCompletedOnboarding)
        XCTAssertEqual(preferences.sttLanguage, .automatic)
        XCTAssertEqual(preferences.sttFavoriteLanguages, [.french, .english])
        XCTAssertTrue(preferences.dictationDictionary.isEmpty)
    }

    func testTranscriptionLanguageCodesAndLegacyMigration() throws {
        XCTAssertEqual(TranscriptionLanguage.french.apiCode, "fr")
        XCTAssertNil(TranscriptionLanguage.automatic.apiCode)
        XCTAssertEqual(TranscriptionLanguage(legacyCode: "fr-FR"), .french)
        XCTAssertEqual(TranscriptionLanguage(legacyCode: "unknown"), .automatic)

        let migrated = try JSONDecoder().decode(
            AppPreferences.self,
            from: Data("{\"schemaVersion\":6,\"sttPrompt\":\"legacy context\",\"dictationDictionary\":[\"  Symfony \",\"CapRover\",\"Symfony\",\"  \"],\"sttLanguage\":\"de-DE\",\"sttFavoriteLanguages\":[\"fr\",\"fr\",\"automatic\",\"invalid\",\"en\"]}".utf8)
        )

        XCTAssertEqual(migrated.sttLanguage, .german)
        XCTAssertEqual(migrated.sttFavoriteLanguages, [.french, .english, .german])
        XCTAssertEqual(migrated.dictationDictionary, ["Symfony", "CapRover"])
        XCTAssertNotEqual(migrated.dictationDictionaryPrompt, "legacy context")
    }

    func testLocalizationDefaultsAndLegacyPromptMigration() throws {
        let fresh = AppPreferences()
        XCTAssertEqual(fresh.interfaceLanguage, .automatic)
        XCTAssertEqual(fresh.cleanupPromptMode, .localizedDefault)

        let legacy = try JSONDecoder().decode(
            AppPreferences.self,
            from: Data("{\"schemaVersion\":4,\"cleanupPrompt\":\"\(AppPreferences.defaultCleanupPrompt)\"}".utf8)
        )
        XCTAssertEqual(legacy.cleanupPromptMode, .legacyDefaultPendingChoice)

        let custom = try JSONDecoder().decode(
            AppPreferences.self,
            from: Data("{\"schemaVersion\":4,\"cleanupPrompt\":\"Keep my wording\"}".utf8)
        )
        XCTAssertEqual(custom.cleanupPromptMode, .custom)
    }

    func testSchemaFiveCustomPromptDecodesAsEditableLibraryEntry() throws {
        let preferences = try JSONDecoder().decode(
            AppPreferences.self,
            from: Data("{\"schemaVersion\":5,\"cleanupPrompt\":\"Keep my wording\",\"cleanupPromptMode\":\"custom\"}".utf8)
        )

        XCTAssertEqual(preferences.cleanupPrompts.count, 1)
        XCTAssertEqual(preferences.cleanupPrompts.first?.name, "Existing Prompt")
        XCTAssertEqual(preferences.cleanupPrompts.first?.instructions, "Keep my wording")
        XCTAssertEqual(preferences.activeCleanupPromptID, preferences.cleanupPrompts.first?.id)
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
