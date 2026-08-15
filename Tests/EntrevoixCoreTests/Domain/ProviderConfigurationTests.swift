import Foundation
import XCTest
@testable import EntrevoixCore

final class ProviderConfigurationTests: XCTestCase {
    func testNormalizesKnownOpenAIRoutes() {
        let cases = [
            (" http://127.0.0.1:8001 ", "//audio/transcriptions//", "http://127.0.0.1:8001/v1/audio/transcriptions"),
            ("https://example.com", "responses", "https://example.com/v1/responses"),
            ("https://example.com/api", "chat/completions", "https://example.com/api/v1/chat/completions")
        ]

        for (baseURL, path, expected) in cases {
            let configuration = ProviderConfiguration(
                name: "Test",
                baseURL: baseURL,
                path: path,
                model: "model",
                authentication: .none
            )
            XCTAssertEqual(configuration.endpointURL?.absoluteString, expected)
        }
    }

    func testDoesNotDuplicateVersionOrExistingRoute() {
        let versioned = ProviderConfiguration(
            name: "Versioned",
            baseURL: "https://api.openai.com/v1",
            path: "responses",
            model: "model"
        )
        let complete = ProviderConfiguration(
            name: "Complete",
            baseURL: "https://api.openai.com/v1/audio/transcriptions",
            path: "audio/transcriptions",
            model: "model"
        )

        XCTAssertEqual(versioned.endpointURL?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(complete.endpointURL?.absoluteString, "https://api.openai.com/v1/audio/transcriptions")
    }

    func testCustomPathIsKeptOutsideV1() {
        let configuration = ProviderConfiguration(
            name: "Custom",
            baseURL: "https://example.com/api",
            path: "/speech/recognize/",
            model: "model"
        )

        XCTAssertEqual(configuration.endpointURL?.absoluteString, "https://example.com/api/speech/recognize")
    }

    func testRejectsInvalidBaseURLs() {
        for baseURL in ["", "api.example.com", "ftp://example.com"] {
            let configuration = ProviderConfiguration(
                name: "Invalid",
                baseURL: baseURL,
                path: "responses",
                model: "model"
            )
            XCTAssertNil(configuration.endpointURL)
        }
    }

    func testProviderDefaults() {
        XCTAssertEqual(ProviderConfiguration.openAITranscription.path, "audio/transcriptions")
        XCTAssertEqual(ProviderConfiguration.openAIResponses.path, "responses")
    }

    func testValidationIssuesAreStableAndOrdered() {
        let configuration = ProviderConfiguration(
            name: "Invalid", baseURL: "not a URL", path: "responses", model: " ",
            authentication: .apiKey, customHeaderName: " "
        )
        XCTAssertEqual(configuration.validationIssues(apiKey: ""), [.invalidEndpoint, .missingModel, .missingHeaderName, .missingAPIKey])
    }

    func testValidationAuthenticationModes() {
        let base = ProviderConfiguration(name: "Test", baseURL: "https://example.com", path: "responses", model: "model")
        XCTAssertTrue(base.validationIssues(apiKey: "").contains(.missingAPIKey))
        var apiKey = base
        apiKey.authentication = .apiKey
        apiKey.customHeaderName = "X-API-Key"
        XCTAssertTrue(apiKey.validationIssues(apiKey: "secret").isEmpty)
        var none = base
        none.authentication = .none
        XCTAssertTrue(none.validationIssues(apiKey: "").isEmpty)
    }
}
