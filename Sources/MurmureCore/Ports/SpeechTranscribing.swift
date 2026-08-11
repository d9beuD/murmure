import Foundation

public protocol SpeechTranscribing: Sendable {
    func transcribe(audioURL: URL, configuration: ProviderConfiguration, apiKey: String, prompt: String?, language: String?) async throws -> String
}
