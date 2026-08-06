import Foundation
import Observation

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
