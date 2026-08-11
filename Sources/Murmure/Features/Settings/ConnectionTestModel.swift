import Foundation
import MurmureCore
import Observation

enum ConnectionTestFailure: Equatable {
    case microphonePermissionDenied
    case recordingFailed(message: UserFacingErrorMessage)
    case insufficientAudio
    case transcriptionFailed(message: UserFacingErrorMessage)
}

enum ConnectionTestState: Equatable {
    case idle
    case requestingPermission
    case recording
    case testing
    case succeeded(characterCount: Int)
    case failed(ConnectionTestFailure)

    var isInactive: Bool {
        switch self {
        case .idle, .succeeded, .failed: true
        case .requestingPermission, .recording, .testing: false
        }
    }
}

enum ConnectionTestEvent: Equatable {
    case recordingStarted
    case recordingStopped
    case succeeded
    case failed
}

@MainActor
@Observable
final class ConnectionTestModel {
    private let audioRecorder: any AudioRecording
    private let microphonePermission: any MicrophonePermissionRequesting
    private let transcriber: any SpeechTranscribing
    private let logger: any LogWriting
    private let now: () -> Date

    private(set) var state: ConnectionTestState = .idle
    var onEvent: ((ConnectionTestEvent) -> Void)?

    private var sessionID: UUID?
    private var startedAt: Date?
    private var task: Task<Void, Never>?

    init(
        audioRecorder: any AudioRecording,
        microphonePermission: any MicrophonePermissionRequesting,
        transcriber: any SpeechTranscribing,
        logger: any LogWriting,
        now: @escaping () -> Date
    ) {
        self.audioRecorder = audioRecorder
        self.microphonePermission = microphonePermission
        self.transcriber = transcriber
        self.logger = logger
        self.now = now
    }

    func start() {
        guard state.isInactive else { return }
        let sessionID = UUID()
        self.sessionID = sessionID
        state = .requestingPermission
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            guard await microphonePermission.requestMicrophonePermission() else {
                guard self.sessionID == sessionID else { return }
                self.sessionID = nil
                self.state = .failed(.microphonePermissionDenied)
                self.logger.log("Error: connection test: Microphone access was denied. Allow Murmure in System Settings.")
                self.onEvent?(.failed)
                return
            }
            guard self.sessionID == sessionID else { return }
            do {
                try self.audioRecorder.start()
                self.startedAt = self.now()
                self.state = .recording
                self.logger.log("Connection test recording started")
                self.onEvent?(.recordingStarted)
            } catch {
                self.sessionID = nil
                self.state = .failed(.recordingFailed(message: userFacingMessage(for: error)))
                self.logger.log("Error: connection test: \(safeLogMessage(for: error))")
                self.onEvent?(.failed)
            }
        }
    }

    func finish(request: TranscriptionRequest) {
        guard state == .recording, let sessionID else { return }
        let duration = startedAt.map { now().timeIntervalSince($0) } ?? 0
        startedAt = nil
        guard duration >= DictationTiming.minimumRecordingDuration,
              let audioURL = audioRecorder.stop() else {
            audioRecorder.cancel()
            self.sessionID = nil
            state = .failed(.insufficientAudio)
            onEvent?(.failed)
            return
        }

        state = .testing
        logger.log("Connection test recording ended")
        onEvent?(.recordingStopped)
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.audioRecorder.deleteLastCapture()
                if self.sessionID == sessionID {
                    self.sessionID = nil
                }
            }
            do {
                let host = request.configuration.endpointURL?.host ?? "configured endpoint"
                self.logger.log("Testing STT connection with \(host)")
                let text = try await self.transcriber.transcribe(
                    audioURL: audioURL,
                    configuration: request.configuration,
                    apiKey: request.apiKey,
                    prompt: request.prompt,
                    language: request.language
                )
                guard self.sessionID == sessionID else { return }
                self.state = .succeeded(characterCount: text.count)
                self.logger.log("STT connection test succeeded (\(text.count) chars)")
                self.onEvent?(.succeeded)
            } catch is CancellationError {
                guard self.sessionID == sessionID else { return }
                self.sessionID = nil
                self.state = .idle
            } catch {
                guard self.sessionID == sessionID else { return }
                self.sessionID = nil
                self.state = .failed(.transcriptionFailed(message: userFacingMessage(for: error)))
                self.logger.log("Error: connection test: \(safeLogMessage(for: error))")
                self.onEvent?(.failed)
            }
        }
    }

    func cancel() {
        sessionID = nil
        task?.cancel()
        task = nil
        startedAt = nil
        audioRecorder.cancel()
        state = .idle
    }
}
