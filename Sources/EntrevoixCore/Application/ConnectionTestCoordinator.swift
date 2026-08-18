import Foundation

public enum ConnectionTestFailure: Equatable, Sendable {
    case invalidConfiguration([ProviderValidationIssue])
    case microphonePermissionDenied
    case recordingFailed(message: UserFacingErrorMessage)
    case insufficientAudio
    case transcriptionFailed(message: UserFacingErrorMessage)
}

public enum ConnectionTestState: Equatable, Sendable {
    case idle
    case requestingPermission
    case recording
    case testing
    case succeeded(characterCount: Int)
    case failed(ConnectionTestFailure)

    public var isInactive: Bool {
        switch self {
        case .idle, .succeeded, .failed: true
        case .requestingPermission, .recording, .testing: false
        }
    }
}

public enum ConnectionTestEvent: Equatable, Sendable {
    case recordingStarted
    case recordingStopped
    case succeeded
    case failed
}

public struct ConnectionTestSnapshot: Equatable, Sendable {
    public let state: ConnectionTestState

    public init(state: ConnectionTestState) { self.state = state }
}

@MainActor
public final class ConnectionTestCoordinator {
    private let audioRecorder: any AudioRecording
    private let microphonePermission: any MicrophonePermissionRequesting
    private let transcriber: any SpeechTranscribing
    private let logger: any LogWriting
    private let now: () -> Date
    private let sessionArbiter: (any SessionArbitrating)?

    public private(set) var state: ConnectionTestState = .idle {
        didSet { onSnapshot?(snapshot) }
    }
    public var onEvent: ((ConnectionTestEvent) -> Void)?
    public var onSnapshot: ((ConnectionTestSnapshot) -> Void)? {
        didSet { onSnapshot?(snapshot) }
    }
    public var snapshot: ConnectionTestSnapshot { ConnectionTestSnapshot(state: state) }

    private var sessionID: UUID?
    private var sessionLease: SessionLease?
    private var startedAt: Date?
    private var task: Task<Void, Never>?

    public convenience init(
        audioRecorder: any AudioRecording,
        microphonePermission: any MicrophonePermissionRequesting,
        transcriber: any SpeechTranscribing,
        logger: any LogWriting,
        sessionArbiter: (any SessionArbitrating)? = nil
    ) {
        self.init(audioRecorder: audioRecorder, microphonePermission: microphonePermission, transcriber: transcriber, logger: logger, now: Date.init, sessionArbiter: sessionArbiter)
    }

    public init(
        audioRecorder: any AudioRecording,
        microphonePermission: any MicrophonePermissionRequesting,
        transcriber: any SpeechTranscribing,
        logger: any LogWriting,
        now: @escaping () -> Date,
        sessionArbiter: (any SessionArbitrating)? = nil
    ) {
        self.audioRecorder = audioRecorder
        self.microphonePermission = microphonePermission
        self.transcriber = transcriber
        self.logger = logger
        self.now = now
        self.sessionArbiter = sessionArbiter
    }

    public func start(request: TranscriptionRequest? = nil) {
        guard state.isInactive else { return }
        if let request {
            let issues = request.configuration.validationIssues(apiKey: request.apiKey)
            guard issues.isEmpty else {
                state = .failed(.invalidConfiguration(issues))
                onEvent?(.failed)
                return
            }
        }
        if let sessionArbiter {
            guard let lease = sessionArbiter.acquire(.connectionTest) else { return }
            sessionLease = lease
        }
        let sessionID = UUID()
        self.sessionID = sessionID
        state = .requestingPermission
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                if let request { try await self.transcriber.preflight(request: request) }
            } catch is CancellationError {
                return
            } catch {
                guard self.sessionID == sessionID else { return }
                self.sessionID = nil
                self.releaseSessionLease()
                self.state = .failed(.transcriptionFailed(message: userFacingMessage(for: error)))
                self.logger.log("Error: connection test preflight: \(safeLogMessage(for: error))")
                self.onEvent?(.failed)
                return
            }
            guard self.sessionID == sessionID else { return }
            guard await self.microphonePermission.requestMicrophonePermission() else {
                guard self.sessionID == sessionID else { return }
                self.sessionID = nil
                self.releaseSessionLease()
                self.state = .failed(.microphonePermissionDenied)
                self.logger.log("Error: connection test: Microphone access was denied. Allow Entrevoix in System Settings.")
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
                self.releaseSessionLease()
                self.state = .failed(.recordingFailed(message: userFacingMessage(for: error)))
                self.logger.log("Error: connection test: \(safeLogMessage(for: error))")
                self.onEvent?(.failed)
            }
        }
    }

    public func finish(request: TranscriptionRequest) {
        guard state == .recording, let sessionID else { return }
        let duration = startedAt.map { now().timeIntervalSince($0) } ?? 0
        startedAt = nil
        guard duration >= DictationTiming.minimumRecordingDuration, let audioURL = audioRecorder.stop() else {
            audioRecorder.cancel()
            self.sessionID = nil
            state = .failed(.insufficientAudio)
            onEvent?(.failed)
            releaseSessionLease()
            return
        }
        state = .testing
        logger.log("Connection test recording ended")
        onEvent?(.recordingStopped)
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.audioRecorder.deleteCapture(at: audioURL)
                if self.sessionID == sessionID { self.sessionID = nil }
                self.releaseSessionLease()
            }
            do {
                let host = request.configuration.endpointURL?.host ?? "configured endpoint"
                self.logger.log("Testing STT connection with \(host)")
                let text = try await self.transcriber.transcribe(audioURL: audioURL, request: request)
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

    public func cancel() {
        sessionID = nil
        task?.cancel()
        task = nil
        startedAt = nil
        audioRecorder.cancel()
        state = .idle
        releaseSessionLease()
    }

    private func releaseSessionLease() {
        guard let sessionLease else { return }
        sessionArbiter?.release(sessionLease)
        self.sessionLease = nil
    }
}
