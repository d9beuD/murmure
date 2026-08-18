import Foundation

/// A stable reference to a provider stored in the user's catalogue.
public enum ProviderIdentifier: Codable, Equatable, Hashable, Sendable, Identifiable {
    case apple
    case remote(UUID)

    public var id: String {
        switch self {
        case .apple: "apple"
        case .remote(let id): id.uuidString
        }
    }

    public var remoteID: UUID? {
        guard case .remote(let id) = self else { return nil }
        return id
    }
}

public enum RemoteProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI
    case openAICompatible

    public var id: Self { self }
}

public struct STTCapability: Codable, Equatable, Sendable {
    public var path: String
    public var model: String

    public init(path: String = "audio/transcriptions", model: String = "gpt-transcribe") {
        self.path = path
        self.model = model
    }
}

public struct TTTCapability: Codable, Equatable, Sendable {
    public var path: String
    public var model: String
    public var format: CleanupAPIFormat

    public init(path: String = "responses", model: String = "gpt-5-mini", format: CleanupAPIFormat = .responses) {
        self.path = path
        self.model = model
        self.format = format
    }
}

public struct RemoteProviderProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var kind: RemoteProviderKind
    public var name: String
    public var baseURL: String
    public var authentication: AuthenticationMode
    public var customHeaderName: String
    public var modelsPath: String
    public var timeout: Double
    public var stt: STTCapability?
    public var ttt: TTTCapability?

    public init(
        id: UUID = UUID(),
        kind: RemoteProviderKind,
        name: String,
        baseURL: String,
        authentication: AuthenticationMode = .bearer,
        customHeaderName: String = "Authorization",
        modelsPath: String = "models",
        timeout: Double = 60,
        stt: STTCapability? = nil,
        ttt: TTTCapability? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.baseURL = baseURL
        self.authentication = authentication
        self.customHeaderName = customHeaderName
        self.modelsPath = modelsPath
        self.timeout = timeout
        self.stt = stt
        self.ttt = ttt
        normalizeFixedOpenAIFields()
    }

    public static func openAI(id: UUID = UUID(), name: String = "OpenAI") -> Self {
        Self(id: id, kind: .openAI, name: name, baseURL: "https://api.openai.com/v1", stt: STTCapability(), ttt: TTTCapability())
    }

    public static func compatible(id: UUID = UUID(), name: String = "OpenAI-compatible") -> Self {
        Self(id: id, kind: .openAICompatible, name: name, baseURL: "", stt: STTCapability(), ttt: nil)
    }

    public mutating func normalizeFixedOpenAIFields() {
        guard kind == .openAI else { return }
        baseURL = "https://api.openai.com/v1"
        authentication = .bearer
        customHeaderName = "Authorization"
        modelsPath = "models"
        if stt != nil { stt?.path = "audio/transcriptions" }
        if var ttt {
            ttt.path = ttt.format == .chatCompletions ? "chat/completions" : "responses"
            self.ttt = ttt
        }
    }

    public func configuration(for capability: ProviderCapability) -> ProviderConfiguration? {
        switch capability {
        case .stt:
            guard let stt else { return nil }
            return ProviderConfiguration(id: id, name: name, baseURL: baseURL, path: stt.path, model: stt.model, authentication: authentication, customHeaderName: customHeaderName, timeout: timeout)
        case .ttt:
            guard let ttt else { return nil }
            return ProviderConfiguration(id: id, name: name, baseURL: baseURL, path: ttt.path, model: ttt.model, authentication: authentication, customHeaderName: customHeaderName, timeout: timeout)
        }
    }
}

public enum ProviderCatalogEntry: Codable, Equatable, Sendable, Identifiable {
    case apple
    case remote(RemoteProviderProfile)

    public var id: ProviderIdentifier {
        switch self {
        case .apple: .apple
        case .remote(let profile): .remote(profile.id)
        }
    }

    public var remoteProfile: RemoteProviderProfile? {
        guard case .remote(let profile) = self else { return nil }
        return profile
    }
}

public enum ProviderCapability: String, Codable, CaseIterable, Sendable {
    case stt
    case ttt
}

public enum ProviderUnavailabilityReason: String, Codable, Equatable, Sendable {
    case missingConfiguration
    case missingAPIKey
    case invalidEndpoint
    case unsupportedDevice
    case appleIntelligenceDisabled
    case modelNotReady
    case unsupportedLocale
    case speechAssetsRequired
    case speechAssetsUnavailable
    case preparationFailed
}

public enum ProviderAvailability: Codable, Equatable, Sendable {
    case available
    case unavailable(ProviderUnavailabilityReason)
}

public enum ProviderPreparationState: Codable, Equatable, Sendable {
    case checking
    case unsupported
    case downloadRequired
    case downloading(progress: Double?)
    case ready
    case failed
}

public struct ProviderUnavailableError: Error, Equatable, Sendable, UserFacingErrorProviding, LogSafeError {
    public let capability: ProviderCapability
    public let reason: ProviderUnavailabilityReason

    public init(capability: ProviderCapability, reason: ProviderUnavailabilityReason) {
        self.capability = capability
        self.reason = reason
    }

    public var userFacingMessage: UserFacingErrorMessage { .verbatim("The selected Apple model is unavailable.") }
    public var logMessage: String { "Apple \(capability.rawValue) unavailable (\(reason.rawValue))." }
}

public enum ProviderValidationIssue: Equatable, Sendable {
    case missingName
    case duplicateName
    case invalidEndpoint
    case missingCapability
    case missingRoute
    case missingModel
    case missingHeaderName
    case missingAPIKey
}

public extension RemoteProviderProfile {
    func validationIssues(apiKey: String, existingNames: [String] = []) -> [ProviderValidationIssue] {
        var issues: [ProviderValidationIssue] = []
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedName.isEmpty { issues.append(.missingName) }
        if existingNames.contains(where: { $0.caseInsensitiveCompare(normalizedName) == .orderedSame }) { issues.append(.duplicateName) }
        if URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))?.url == nil { issues.append(.invalidEndpoint) }
        if stt == nil && ttt == nil { issues.append(.missingCapability) }
        for capability in [stt.map { ($0.path, $0.model) }, ttt.map { ($0.path, $0.model) }].compactMap({ $0 }) {
            if capability.0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingRoute) }
            if capability.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingModel) }
        }
        if authentication == .apiKey && customHeaderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingHeaderName) }
        if authentication != .none && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingAPIKey) }
        return issues
    }
}

public extension ProviderConfiguration {
    /// Compatibility validation for schema-8 request paths. New catalogue drafts
    /// should use `RemoteProviderProfile.validationIssues` instead.
    func validationIssues(apiKey: String) -> [ProviderValidationIssue] {
        var issues: [ProviderValidationIssue] = []
        if endpointURL == nil { issues.append(.invalidEndpoint) }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingModel) }
        if authentication == .apiKey, customHeaderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingHeaderName) }
        if authentication != .none, apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingAPIKey) }
        return issues
    }
}
