import Foundation

public struct TranscriptionRequest: Sendable {
    public let configuration: ProviderConfiguration
    public let apiKey: String
    public let prompt: String?
    public let language: String?

    public init(
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.prompt = prompt
        self.language = language
    }
}

public struct CleanupRequest: Sendable {
    public let configuration: ProviderConfiguration
    public let apiKey: String
    public let format: CleanupAPIFormat
    public let prompt: String
    public let failurePolicy: CleanupFailurePolicy

    public init(
        configuration: ProviderConfiguration,
        apiKey: String,
        format: CleanupAPIFormat,
        prompt: String,
        failurePolicy: CleanupFailurePolicy
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.format = format
        self.prompt = prompt
        self.failurePolicy = failurePolicy
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
