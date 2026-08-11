import Foundation
import Observation

/// Errors that can be safely written to the live diagnostic log.
///
/// Network providers may include user input in an error payload, so callers
/// must never fall back to `localizedDescription` for an unknown error.
public protocol LogSafeError: Error {
    var logMessage: String { get }
}

public func safeLogMessage(for error: any Error) -> String {
    if let error = error as? any LogSafeError {
        return error.logMessage
    }
    return "Operation failed with no exportable details."
}

public struct AppLogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let message: String

    public init(id: UUID = UUID(), date: Date = Date(), message: String) {
        self.id = id
        self.date = date
        self.message = message
    }
}

@MainActor
@Observable
public final class AppLogStore {
    public private(set) var entries: [AppLogEntry] = []

    public init() {}

    public func log(_ message: String) {
        entries.append(AppLogEntry(message: message))
    }

    public func clear() {
        entries.removeAll()
    }
}
