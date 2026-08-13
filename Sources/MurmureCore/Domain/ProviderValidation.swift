import Foundation

public enum ProviderValidationIssue: Equatable, Sendable {
    case invalidEndpoint
    case missingModel
    case missingHeaderName
    case missingAPIKey
}

public extension ProviderConfiguration {
    /// Returns deterministic, presentation-neutral validation issues.
    func validationIssues(apiKey: String) -> [ProviderValidationIssue] {
        var issues: [ProviderValidationIssue] = []
        if endpointURL == nil { issues.append(.invalidEndpoint) }
        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.missingModel) }
        if authentication == .apiKey,
           customHeaderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingHeaderName)
        }
        if authentication != .none,
           apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingAPIKey)
        }
        return issues
    }
}
