import Foundation

public enum TriggerMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case pushToTalk
    case toggle
    public var id: Self { self }
}

public enum DictationTiming {
    public static let minimumRecordingDuration: TimeInterval = 0.25
    public static let maximumRecordingDuration: TimeInterval = 10 * 60
    public static let shortcutDebounce: TimeInterval = 0.15
}

public enum DictationFailure: Equatable, Sendable {
    case microphonePermissionDenied
    case recordingFailed(message: String)
    case audioUnavailable
    case sessionUnavailable
    case transcriptionFailed(message: String)
    case cleanupFailed(message: String)
}

public enum DictationState: Equatable, Sendable {
    case idle
    case requestingPermission
    case recording
    case transcribing
    case error(DictationFailure)
}
