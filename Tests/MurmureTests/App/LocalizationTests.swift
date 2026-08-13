import Foundation
import XCTest
import MurmureCore
@testable import Murmure

final class LocalizationTests: XCTestCase {
    func testExplicitAndAutomaticLanguageResolution() {
        XCTAssertEqual(MurmureLocalization.locale(for: .english).identifier, "en")
        XCTAssertEqual(MurmureLocalization.locale(for: .french).identifier, "fr-FR")
        XCTAssertEqual(
            MurmureLocalization.locale(for: .automatic, preferredLanguages: ["fr-CA", "en-US"]).identifier,
            "fr-FR"
        )
        XCTAssertEqual(
            MurmureLocalization.locale(for: .automatic, preferredLanguages: ["de-DE"]).identifier,
            "en"
        )
        XCTAssertEqual(
            MurmureLocalization.locale(for: .automatic, preferredLanguages: ["de-DE", "fr-CA"]).identifier,
            "fr-FR"
        )
    }

    func testCatalogContainsEnglishAndFrenchRepresentativeEntries() throws {
        let data = try XCTUnwrap(MurmureLocalization.sourceCatalogData())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(object["strings"] as? [String: Any])

        for key in [
            "cleanup.default_prompt",
            "menu.settings",
            "settings.interface_language",
            "field.stt_language",
            "field.stt_favorite_languages",
            "menu.language",
            "language.french",
            "language.german",
            "connection_test.received_characters",
            "dictation.transcribing",
            "dictation.improving",
            "action.quit",
            "startup.incompatible.title",
            "startup.incompatible.message",
            "startup.recovered.title",
            "startup.recovered.message"
        ] {
            let entry = try XCTUnwrap(strings[key] as? [String: Any])
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
            XCTAssertNotNil(localizations["en"])
            XCTAssertNotNil(localizations["fr-FR"])
        }

        XCTAssertEqual(TranscriptionLanguage.french.title(locale: Locale(identifier: "en")), "French")
        XCTAssertEqual(TranscriptionLanguage.french.title(locale: Locale(identifier: "fr-FR")), "Français")

        let englishOrder = TranscriptionLanguage.sortedForDisplay(locale: Locale(identifier: "en"))
        XCTAssertEqual(englishOrder.first, .arabic)
        XCTAssertEqual(englishOrder.last, .vietnamese)

        let frenchOrder = TranscriptionLanguage.sortedForDisplay(locale: Locale(identifier: "fr-FR"))
        XCTAssertEqual(frenchOrder.first, .german)
        XCTAssertEqual(frenchOrder.last, .vietnamese)

    }

    func testApplicationBundleResourcePathUsesContentsResources() {
        let appURL = URL(fileURLWithPath: "/tmp/Murmure.app")
        let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)

        XCTAssertEqual(
            MurmureLocalization.applicationResourceBundleURL(bundleURL: appURL, resourceURL: resourcesURL),
            resourcesURL.appendingPathComponent("Murmure_Murmure.bundle", isDirectory: true)
        )
        XCTAssertNil(
            MurmureLocalization.applicationResourceBundleURL(
                bundleURL: URL(fileURLWithPath: "/tmp/Murmure_Murmure.bundle"),
                resourceURL: resourcesURL
            )
        )
    }

    func testUserFacingErrorKeepsProviderDetails() {
        let message = UserFacingErrorMessage.sttHTTP(statusCode: 503, providerMessage: "Provider unavailable")
        XCTAssertEqual(message.localizedText(locale: Locale(identifier: "en")), "STT error (HTTP 503).: Provider unavailable")
    }
}
