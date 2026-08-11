import Foundation
import XCTest
@testable import MurmureCore

enum StubError: LocalizedError, LogSafeError, Sendable {
    case failure

    var errorDescription: String? { "Visible failure" }
    var logMessage: String { "Safe failure" }
}

@MainActor
final class RecorderSpy: AudioRecording {
    var startError: (any Error)?
    var stopURL: URL?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0
    private(set) var deleteCount = 0

    func start() throws {
        startCount += 1
        if let startError { throw startError }
    }

    func stop() -> URL? {
        stopCount += 1
        return stopURL
    }

    func cancel() { cancelCount += 1 }
    func deleteLastCapture() { deleteCount += 1 }
}

@MainActor
final class PendingPermissionRecorder: AudioRecording {
    private(set) var startCount = 0
    private(set) var cancelCount = 0

    func start() throws { startCount += 1 }
    func stop() -> URL? { nil }
    func cancel() { cancelCount += 1 }
    func deleteLastCapture() {}
}

@MainActor
final class PermissionSpy: MicrophonePermissionRequesting {
    var permission = true

    func requestMicrophonePermission() async -> Bool {
        return permission
    }
}

@MainActor
final class PendingPermissionProvider: MicrophonePermissionRequesting {
    private var continuation: CheckedContinuation<Bool, Never>?

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation = $0 }
    }

    func resolvePermission(_ granted: Bool) {
        continuation?.resume(returning: granted)
        continuation = nil
    }
}

struct TestLogEntry: Equatable, Sendable {
    let message: String
}

@MainActor
final class TestLogStore: LogWriting {
    private(set) var entries: [TestLogEntry] = []

    func log(_ message: String) {
        entries.append(TestLogEntry(message: message))
    }
}

actor TranscriberSpy: SpeechTranscribing {
    struct Call: Sendable {
        let audioURL: URL
        let configuration: ProviderConfiguration
        let apiKey: String
        let prompt: String?
        let language: String?
    }

    private let result: Result<String, StubError>
    private(set) var calls: [Call] = []

    init(result: Result<String, StubError> = .success("raw transcript")) {
        self.result = result
    }

    func transcribe(
        audioURL: URL,
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?
    ) async throws -> String {
        calls.append(Call(
            audioURL: audioURL,
            configuration: configuration,
            apiKey: apiKey,
            prompt: prompt,
            language: language
        ))
        return try result.get()
    }
}

actor ControlledTranscriber: SpeechTranscribing {
    private var continuation: CheckedContinuation<String, Never>?
    private(set) var callCount = 0

    func transcribe(
        audioURL: URL,
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?
    ) async throws -> String {
        callCount += 1
        return await withCheckedContinuation { continuation = $0 }
    }

    func succeed(with text: String) {
        continuation?.resume(returning: text)
        continuation = nil
    }
}

actor CleanerSpy: TextCleaning {
    struct Call: Sendable {
        let text: String
        let configuration: ProviderConfiguration
        let apiKey: String
        let format: CleanupAPIFormat
        let prompt: String
    }

    private let result: Result<String, StubError>
    private(set) var calls: [Call] = []

    init(result: Result<String, StubError> = .success("clean transcript")) {
        self.result = result
    }

    func clean(
        text: String,
        configuration: ProviderConfiguration,
        apiKey: String,
        format: CleanupAPIFormat,
        prompt: String
    ) async throws -> String {
        calls.append(Call(
            text: text,
            configuration: configuration,
            apiKey: apiKey,
            format: format,
            prompt: prompt
        ))
        return try result.get()
    }
}

@MainActor
final class DeliverySpy: TextDelivering {
    var result: TextDeliveryResult = .copied
    private(set) var copiedTexts: [String] = []
    private(set) var pastedTexts: [String] = []
    private(set) var deliveries: [(String, OutputMode)] = []

    func copy(_ text: String) { copiedTexts.append(text) }
    func copyAndPaste(_ text: String) { pastedTexts.append(text) }

    func deliver(_ text: String, mode: OutputMode) -> TextDeliveryResult {
        deliveries.append((text, mode))
        return result
    }
}

@MainActor
final class MutableDate {
    var value = Date(timeIntervalSince1970: 1_000)
    func advance(by interval: TimeInterval) { value.addTimeInterval(interval) }
}

@MainActor
func waitUntil(
    _ description: String,
    iterations: Int = 1_000,
    condition: @escaping @MainActor () async -> Bool
) async {
    for _ in 0..<iterations {
        if await condition() { return }
        await Task.yield()
    }
    XCTFail("Timed out waiting for \(description)")
}

func temporaryAudioFile(contents: Data = Data("audio".utf8)) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("murmure-tests-\(UUID().uuidString)")
        .appendingPathExtension("wav")
    try contents.write(to: url)
    return url
}

let testSTTConfiguration = ProviderConfiguration(
    name: "Test STT",
    baseURL: "https://stt.example.com/v1",
    path: "audio/transcriptions",
    model: "test-model"
)

@MainActor
func stopCoordinator(
    _ coordinator: DictationCoordinator,
    cleanupEnabled: Bool = false,
    cleanupFailurePolicy: CleanupFailurePolicy = .useRawTranscript,
    outputMode: OutputMode = .clipboard
) {
    coordinator.stopRecording(request: DictationRequest(
        transcription: TranscriptionRequest(
            configuration: testSTTConfiguration,
            apiKey: "stt-secret",
            prompt: "prompt",
            language: "fr"
        ),
        cleanup: cleanupEnabled ? CleanupRequest(
            configuration: .openAIResponses,
            apiKey: "cleanup-secret",
            format: .responses,
            prompt: "clean it",
            failurePolicy: cleanupFailurePolicy
        ) : nil,
        outputMode: outputMode
    ))
}
