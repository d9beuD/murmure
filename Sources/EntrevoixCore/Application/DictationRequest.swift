import Foundation

public enum TranscriptionTarget: Sendable {
    case remote
    case apple(localeIdentifier: String?, dictionaryTerms: [String])
}

public enum CleanupTarget: Sendable {
    case remote
    case apple(localeIdentifier: String?)
}

public struct TranscriptionRequest: Sendable {
    public let configuration: ProviderConfiguration
    public let apiKey: String
    public let prompt: String?
    public let language: String?
    public let target: TranscriptionTarget

    public init(
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?,
        target: TranscriptionTarget = .remote
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.prompt = prompt
        self.language = language
        self.target = target
    }
}

public struct CleanupRequest: Sendable {
    public let configuration: ProviderConfiguration
    public let apiKey: String
    public let format: CleanupAPIFormat
    public let prompt: String
    public let failurePolicy: CleanupFailurePolicy
    public let target: CleanupTarget

    public init(
        configuration: ProviderConfiguration,
        apiKey: String,
        format: CleanupAPIFormat,
        prompt: String,
        failurePolicy: CleanupFailurePolicy,
        target: CleanupTarget = .remote
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.format = format
        self.prompt = prompt
        self.failurePolicy = failurePolicy
        self.target = target
    }
}

public struct DictationRequest: Sendable {
    public let transcription: TranscriptionRequest
    public let cleanup: CleanupRequest?
    public let outputMode: OutputMode

    public init(
        transcription: TranscriptionRequest,
        cleanup: CleanupRequest?,
        outputMode: OutputMode
    ) {
        self.transcription = transcription
        self.cleanup = cleanup
        self.outputMode = outputMode
    }
}
