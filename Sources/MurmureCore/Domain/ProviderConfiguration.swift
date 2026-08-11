import Foundation

public enum AuthenticationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case bearer
    case apiKey
    case none
    public var id: Self { self }
}

public struct ProviderConfiguration: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var baseURL: String
    public var path: String
    public var model: String
    public var authentication: AuthenticationMode
    public var customHeaderName: String
    public var timeout: Double

    public init(
        id: UUID = UUID(), name: String, baseURL: String, path: String, model: String,
        authentication: AuthenticationMode = .bearer,
        customHeaderName: String = "Authorization", timeout: Double = 60
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.path = path
        self.model = model
        self.authentication = authentication
        self.customHeaderName = customHeaderName
        self.timeout = timeout
    }

    public var endpointURL: URL? {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: base), components.scheme == "https" || components.scheme == "http" else { return nil }
        var basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedSuffix = suffix.lowercased()
        let knownOpenAIRoute = ["audio/transcriptions", "responses", "chat/completions"].contains(normalizedSuffix)
        if knownOpenAIRoute, basePath.split(separator: "/").contains("v1") == false, basePath.hasSuffix(suffix) == false {
            basePath = basePath.isEmpty ? "v1" : "\(basePath)/v1"
        }
        if basePath.hasSuffix(suffix) == false {
            basePath = basePath.isEmpty ? suffix : "\(basePath)/\(suffix)"
        }
        components.path = "/" + basePath
        return components.url
    }
}

public extension ProviderConfiguration {
    static let openAITranscription = ProviderConfiguration(name: "OpenAI STT", baseURL: "https://api.openai.com/v1", path: "audio/transcriptions", model: "gpt-transcribe")
    static let openAIResponses = ProviderConfiguration(name: "OpenAI TTT", baseURL: "https://api.openai.com/v1", path: "responses", model: "gpt-5-mini")
}
