public enum DictationEvent: Equatable, Sendable {
    case recordingStarted
    case recordingStopped
    case cleanupStarted
    case recordingTimedOut
    case sessionEnded
}
