import Foundation
import XCTest
@testable import EntrevoixCore

final class DictationCoordinatorTests: XCTestCase {
    @MainActor
    func testPermissionDeniedAndErrorDismissal() async {
        let recorder = RecorderSpy()
        let permission = PermissionSpy()
        permission.permission = false
        let context = makeContext(recorder: recorder, permission: permission)

        context.coordinator.startRecording()
        await waitUntil("permission failure") { context.coordinator.state != .requestingPermission }

        XCTAssertEqual(
            context.coordinator.state,
            .error(.microphonePermissionDenied)
        )
        XCTAssertTrue(context.logs.entries.last?.message.hasPrefix("Error: Microphone access") == true)
        context.coordinator.startRecording()
        XCTAssertNotEqual(context.coordinator.state, .requestingPermission)
        context.coordinator.dismissError()
        XCTAssertEqual(context.coordinator.state, .idle)
        context.coordinator.dismissError()
        XCTAssertEqual(context.coordinator.state, .idle)
    }

    @MainActor
    func testCancelWhilePermissionIsPendingIgnoresLateGrant() async {
        let recorder = RecorderSpy()
        let permission = PendingPermissionProvider()
        let context = makeContext(recorder: recorder, permission: permission)

        context.coordinator.startRecording()
        XCTAssertEqual(context.coordinator.state, .requestingPermission)
        await Task.yield()
        context.coordinator.cancelRecording()
        permission.resolvePermission(true)
        await Task.yield()

        XCTAssertEqual(context.coordinator.state, .idle)
        XCTAssertEqual(recorder.startCount, 0)
        XCTAssertEqual(recorder.cancelCount, 1)
    }

    @MainActor
    func testRecorderStartFailureUsesSafeLog() async {
        let recorder = RecorderSpy()
        recorder.startError = StubError.failure
        let context = makeContext(recorder: recorder)

        context.coordinator.startRecording()
        await waitUntil("start error") { context.coordinator.state != .requestingPermission }

        XCTAssertEqual(context.coordinator.state, .error(.recordingFailed(message: "Visible failure")))
        XCTAssertEqual(context.logs.entries.last?.message, "Error: Safe failure")
    }

    @MainActor
    func testShortRecordingIsCancelledWithoutTranscription() async {
        let recorder = RecorderSpy()
        let transcriber = TranscriberSpy()
        let context = makeContext(recorder: recorder, transcriber: transcriber)

        context.coordinator.startRecording()
        await waitUntil("recording") { context.coordinator.state == .recording }
        stopCoordinator(context.coordinator)

        XCTAssertEqual(context.coordinator.state, .idle)
        XCTAssertEqual(recorder.cancelCount, 1)
        XCTAssertEqual(recorder.stopCount, 0)
        let calls = await transcriber.calls
        XCTAssertTrue(calls.isEmpty)
        XCTAssertTrue(context.logs.entries.contains { $0.message.contains("less than 250 ms") })
    }

    @MainActor
    func testMissingAudioFileEntersError() async {
        let recorder = RecorderSpy()
        let context = makeContext(recorder: recorder)

        context.coordinator.startRecording()
        await waitUntil("recording") { context.coordinator.state == .recording }
        context.clock.advance(by: 1)
        stopCoordinator(context.coordinator)

        XCTAssertEqual(context.coordinator.state, .error(.audioUnavailable))
        XCTAssertEqual(recorder.stopCount, 1)
    }

    @MainActor
    func testSuccessfulTranscriptionForwardsArgumentsDeletesAudioAndCallsHooks() async throws {
        let recorder = RecorderSpy()
        let audioURL = try temporaryAudioFile()
        recorder.stopURL = audioURL
        let transcriber = TranscriberSpy(result: .success("Hello Entrevoix"))
        let cleaner = CleanerSpy()
        let delivery = DeliverySpy()
        let context = makeContext(recorder: recorder, transcriber: transcriber, cleaner: cleaner, delivery: delivery)
        var started = 0
        var stopped = 0
        context.coordinator.onRecordingStarted = { started += 1 }
        context.coordinator.onRecordingStopped = { stopped += 1 }

        context.coordinator.startRecording()
        await waitUntil("recording") { context.coordinator.state == .recording }
        context.clock.advance(by: 1)
        stopCoordinator(context.coordinator, outputMode: .paste)
        await waitUntil("delivery") { context.coordinator.state == .idle }

        let calls = await transcriber.calls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].configuration, testSTTConfiguration)
        XCTAssertEqual(calls[0].apiKey, "stt-secret")
        XCTAssertEqual(calls[0].prompt, "prompt")
        XCTAssertEqual(calls[0].language, "fr")
        XCTAssertEqual(delivery.deliveries.first?.0, "Hello Entrevoix")
        XCTAssertEqual(delivery.deliveries.first?.1, .paste)
        XCTAssertEqual(context.coordinator.lastTranscript, "Hello Entrevoix")
        let cleanerCalls = await cleaner.calls
        XCTAssertTrue(cleanerCalls.isEmpty)
        XCTAssertEqual(started, 1)
        XCTAssertEqual(stopped, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertNil(context.coordinator.lastAudioURL)
    }

    @MainActor
    func testCleanupSuccessUsesEnhancedText() async throws {
        let recorder = RecorderSpy()
        recorder.stopURL = try temporaryAudioFile()
        let cleaner = CleanerSpy(result: .success("cleaned"))
        let delivery = DeliverySpy()
        let context = makeContext(recorder: recorder, cleaner: cleaner, delivery: delivery)

        await recordAndStop(context, cleanupEnabled: true)

        XCTAssertEqual(context.coordinator.lastTranscript, "cleaned")
        XCTAssertEqual(delivery.deliveries.first?.0, "cleaned")
        let calls = await cleaner.calls
        XCTAssertEqual(calls.first?.text, "raw transcript")
        XCTAssertEqual(calls.first?.apiKey, "cleanup-secret")
        XCTAssertEqual(calls.first?.prompt, "clean it")
    }

    @MainActor
    func testCleanupFailureCanUseRawTranscriptOrStop() async throws {
        for policy in [CleanupFailurePolicy.useRawTranscript, .stop] {
            let recorder = RecorderSpy()
            recorder.stopURL = try temporaryAudioFile()
            let cleaner = CleanerSpy(result: .failure(.failure))
            let delivery = DeliverySpy()
            let context = makeContext(recorder: recorder, cleaner: cleaner, delivery: delivery)

            await recordAndStop(context, cleanupEnabled: true, cleanupFailurePolicy: policy)

            XCTAssertEqual(context.coordinator.lastTranscript, "raw transcript")
            if policy == .useRawTranscript {
                XCTAssertEqual(context.coordinator.state, .idle)
                XCTAssertEqual(delivery.deliveries.count, 1)
                XCTAssertTrue(context.logs.entries.contains { $0.message.contains("Using raw transcription") })
            } else {
                XCTAssertEqual(context.coordinator.state, .error(.cleanupFailed(message: "Visible failure")))
                XCTAssertTrue(delivery.deliveries.isEmpty)
            }
            XCTAssertFalse(context.logs.entries.contains { $0.message.contains("cleanup-secret") })
        }
    }

    @MainActor
    func testTranscriptionFailureIsSafeAndDeletesAudio() async throws {
        let recorder = RecorderSpy()
        let audioURL = try temporaryAudioFile()
        recorder.stopURL = audioURL
        let transcriber = TranscriberSpy(result: .failure(.failure))
        let context = makeContext(recorder: recorder, transcriber: transcriber)

        await recordAndStop(context)

        XCTAssertEqual(context.coordinator.state, .error(.transcriptionFailed(message: "Visible failure")))
        XCTAssertEqual(context.logs.entries.last?.message, "Error: Safe failure")
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
    }

    @MainActor
    func testCancellationIgnoresLateTranscriptionAndDeletesAudio() async throws {
        let recorder = RecorderSpy()
        let audioURL = try temporaryAudioFile()
        recorder.stopURL = audioURL
        let transcriber = ControlledTranscriber()
        let delivery = DeliverySpy()
        let context = makeContext(recorder: recorder, transcriber: transcriber, delivery: delivery)

        context.coordinator.startRecording()
        await waitUntil("recording") { context.coordinator.state == .recording }
        context.clock.advance(by: 1)
        stopCoordinator(context.coordinator)
        await waitUntil("transcriber call") { await transcriber.callCount == 1 }
        context.coordinator.cancelRecording()
        await transcriber.succeed(with: "late secret transcript")
        await waitUntil("audio deletion") { !FileManager.default.fileExists(atPath: audioURL.path) }

        XCTAssertEqual(context.coordinator.state, .idle)
        XCTAssertTrue(delivery.deliveries.isEmpty)
        XCTAssertFalse(context.logs.entries.contains { $0.message.contains("late secret transcript") })
    }

    @MainActor
    func testDeliveryResultsProduceExpectedLogs() async throws {
        let cases: [(TextDeliveryResult, String)] = [
            (.copied, "Delivered transcription to clipboard"),
            (.inserted, "Inserted transcription in active field"),
            (.fallbackCopied(reason: "denied"), "Automatic insertion unavailable; copied to clipboard (denied)"),
            (.secureFieldCopied, "Secure field detected; copied to clipboard")
        ]

        for (result, expectedLog) in cases {
            let recorder = RecorderSpy()
            recorder.stopURL = try temporaryAudioFile()
            let delivery = DeliverySpy()
            delivery.result = result
            let context = makeContext(recorder: recorder, delivery: delivery)
            await recordAndStop(context)
            XCTAssertTrue(context.logs.entries.contains { $0.message == expectedLog })
        }
    }

    @MainActor
    func testWatchdogAndDeleteLastCapture() async {
        let recorder = RecorderSpy()
        let context = makeContext(recorder: recorder, sleep: { _ in })
        var timeoutCount = 0
        context.coordinator.onRecordingTimeout = { timeoutCount += 1 }

        context.coordinator.startRecording()
        await waitUntil("watchdog") { timeoutCount == 1 }
        context.coordinator.deleteLastCapture()

        XCTAssertEqual(recorder.deleteCount, 1)
        context.coordinator.cancelRecording()
    }

    @MainActor
    private func recordAndStop(
        _ context: Context,
        cleanupEnabled: Bool = false,
        cleanupFailurePolicy: CleanupFailurePolicy = .useRawTranscript
    ) async {
        context.coordinator.startRecording()
        await waitUntil("recording") { context.coordinator.state == .recording }
        context.clock.advance(by: 1)
        stopCoordinator(
            context.coordinator,
            cleanupEnabled: cleanupEnabled,
            cleanupFailurePolicy: cleanupFailurePolicy
        )
        await waitUntil("terminal state") {
            context.coordinator.state == .idle || {
                if case .error = context.coordinator.state { return true }
                return false
            }()
        }
    }

    @MainActor
    private func makeContext(
        recorder: any AudioRecording = RecorderSpy(),
        transcriber: any SpeechTranscribing = TranscriberSpy(),
        cleaner: any TextCleaning = CleanerSpy(),
        delivery: DeliverySpy = DeliverySpy(),
        permission: any MicrophonePermissionRequesting = PermissionSpy(),
        sleep: @escaping (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) -> Context {
        let clock = MutableDate()
        let logs = TestLogStore()
        let dependencies = DictationDependencies(
            audioRecorder: recorder,
            microphonePermission: permission,
            textDelivery: delivery,
            transcriber: transcriber,
            cleaner: cleaner,
            logger: logs
        )
        return Context(
            coordinator: DictationCoordinator(
                dependencies: dependencies,
                now: { clock.value },
                sleep: sleep
            ),
            clock: clock,
            logs: logs,
            delivery: delivery
        )
    }
}

@MainActor
private struct Context {
    let coordinator: DictationCoordinator
    let clock: MutableDate
    let logs: TestLogStore
    let delivery: DeliverySpy
}
