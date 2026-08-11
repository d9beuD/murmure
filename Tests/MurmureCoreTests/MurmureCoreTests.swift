import Foundation
import XCTest
@testable import MurmureCore

final class MurmureCoreTests: XCTestCase {
    func testNormalizesOpenAICompatibleEndpoint() {
        let configuration = ProviderConfiguration(
            name: "Local",
            baseURL: "http://127.0.0.1:8001",
            path: "audio/transcriptions",
            model: "whisper-1",
            authentication: .none
        )

        XCTAssertEqual(configuration.endpointURL?.absoluteString, "http://127.0.0.1:8001/v1/audio/transcriptions")
    }

    func testKeepsExistingVersionedEndpoint() {
        let configuration = ProviderConfiguration(
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            path: "responses",
            model: "gpt-5-mini"
        )

        XCTAssertEqual(configuration.endpointURL?.absoluteString, "https://api.openai.com/v1/responses")
    }

    func testMigratesLegacyPreferencesWithoutOnboarding() throws {
        let preferences = AppPreferences(schemaVersion: 3)
        let data = try JSONEncoder().encode(preferences)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return XCTFail("Encoded preferences must be a JSON object.")
        }
        object.removeValue(forKey: "hasCompletedOnboarding")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(AppPreferences.self, from: legacyData)
        XCTAssertTrue(decoded.hasCompletedOnboarding)
    }

    func testRedactsUnknownErrorsFromLogs() {
        let error = SensitiveError()

        XCTAssertEqual(safeLogMessage(for: error), "Operation failed with no exportable details.")
        XCTAssertFalse(safeLogMessage(for: error).contains(error.errorDescription ?? ""))
    }

    @MainActor
    func testDeliversTranscriptionAfterRecording() async {
        let recorder = FakeRecorder()
        let delivery = FakeDelivery()
        let logs = AppLogStore()
        let environment = AppEnvironment(
            audioRecorder: recorder,
            textDelivery: delivery,
            transcriber: SuccessfulTranscriber(),
            cleaner: PassthroughCleaner(),
            logStore: logs
        )
        let coordinator = DictationCoordinator(environment: environment)

        coordinator.startRecording()
        for _ in 0..<100 where coordinator.state != .recording {
            await Task.yield()
        }
        XCTAssertEqual(coordinator.state, .recording)

        try? await Task.sleep(nanoseconds: 300_000_000)
        coordinator.stopRecording(
            configuration: ProviderConfiguration(
                name: "Test",
                baseURL: "http://127.0.0.1:8001",
                path: "audio/transcriptions",
                model: "test",
                authentication: .none
            ),
            apiKey: "",
            prompt: nil,
            language: nil,
            cleanupEnabled: false,
            cleanupConfiguration: .openAIResponses,
            cleanupAPIKey: "",
            cleanupFormat: .responses,
            cleanupPrompt: "unused",
            cleanupFailurePolicy: .useRawTranscript,
            outputMode: .clipboard
        )
        for _ in 0..<100 where coordinator.state != .idle {
            await Task.yield()
        }

        XCTAssertEqual(coordinator.lastTranscript, "Hello Murmure")
        XCTAssertEqual(delivery.copiedTexts, ["Hello Murmure"])
        XCTAssertTrue(logs.entries.contains { $0.message == "Delivered transcription to clipboard" })
    }
}

private struct SensitiveError: LocalizedError {
    var errorDescription: String? { "the secret transcript" }
}

@MainActor
private final class FakeRecorder: AudioRecording {
    private let url = URL(fileURLWithPath: "/tmp/murmure-test.wav")

    func requestPermission() async -> Bool { true }
    func start() throws {}
    func stop() -> URL? { url }
    func cancel() {}
    func deleteLastCapture() {}
}

private struct SuccessfulTranscriber: SpeechTranscribing {
    func transcribe(
        audioURL: URL,
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?
    ) async throws -> String {
        "Hello Murmure"
    }
}

private struct PassthroughCleaner: TextCleaning {
    func clean(
        text: String,
        configuration: ProviderConfiguration,
        apiKey: String,
        format: CleanupAPIFormat,
        prompt: String
    ) async throws -> String {
        text
    }
}

@MainActor
private final class FakeDelivery: TextDelivering {
    private(set) var copiedTexts: [String] = []

    func copy(_ text: String) {
        copiedTexts.append(text)
    }

    func copyAndPaste(_ text: String) {
        copiedTexts.append(text)
    }

    func deliver(_ text: String, mode: OutputMode) -> TextDeliveryResult {
        copiedTexts.append(text)
        return .copied
    }
}
