public enum DictationEvent: Equatable, Sendable {
    case recordingStarted
    case recordingStopped
    case cleanupStarted
    case recordingTimedOut
    case providerUnavailable(capability: ProviderCapability, reason: ProviderUnavailabilityReason)
    case sessionEnded
}
