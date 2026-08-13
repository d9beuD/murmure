import Foundation

public enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

@MainActor
public protocol PermissionProviding: MicrophonePermissionRequesting {
    var microphonePermission: PermissionStatus { get }
    var accessibilityPermission: PermissionStatus { get }
    func requestAccessibilityPermission()
}

@MainActor
public protocol HotkeyHandling: AnyObject {
    var onKeyDown: (() -> Void)? { get set }
    var onKeyUp: (() -> Void)? { get set }
    var onEscape: (() -> Void)? { get set }
}

@MainActor
public protocol LaunchAtLoginControlling: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public enum FeedbackEvent: Equatable, Sendable {
    case recordingStarted
    case recordingStopped
    case connectionTestSucceeded
    case error
}

@MainActor
public protocol FeedbackPlaying: AnyObject {
    func play(_ event: FeedbackEvent)
}
