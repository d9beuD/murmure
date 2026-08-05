import Foundation
import Observation

public enum TriggerMode: String, CaseIterable, Identifiable, Sendable {
    case pushToTalk
    case toggle

    public var id: Self { self }

    public var title: String {
        switch self {
        case .pushToTalk:
            "Maintenir pour parler"
        case .toggle:
            "Appuyer pour démarrer/arrêter"
        }
    }
}

public enum DictationState: Equatable, Sendable {
    case idle
    case recording
    case error(String)

    public var title: String {
        switch self {
        case .idle:
            "Prêt"
        case .recording:
            "Enregistrement…"
        case .error(let message):
            message
        }
    }
}

@MainActor
public protocol AudioRecording: AnyObject {
    func start() throws
    func stop() -> URL?
    func cancel()
    func deleteLastCapture()
}

@MainActor
public protocol TextDelivering: AnyObject {
    func copy(_ text: String)
    func copyAndPaste(_ text: String)
}

@MainActor
public struct AppEnvironment {
    public let audioRecorder: any AudioRecording
    public let textDelivery: any TextDelivering

    public init(
        audioRecorder: any AudioRecording,
        textDelivery: any TextDelivering
    ) {
        self.audioRecorder = audioRecorder
        self.textDelivery = textDelivery
    }
}

@MainActor
@Observable
public final class DictationCoordinator {
    public private(set) var state: DictationState = .idle
    public private(set) var lastAudioURL: URL?

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func startRecording() {
        guard state != .recording else { return }

        do {
            try environment.audioRecorder.start()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func stopRecording() {
        guard state == .recording else { return }
        lastAudioURL = environment.audioRecorder.stop()
        state = .idle
    }

    public func cancelRecording() {
        environment.audioRecorder.cancel()
        state = .idle
    }

    public func deleteLastCapture() {
        environment.audioRecorder.deleteLastCapture()
        lastAudioURL = nil
    }
}
