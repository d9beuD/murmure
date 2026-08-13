import Foundation
import Observation
import MurmureCore

@MainActor
@Observable
final class AppLogStore: LogWriting {
    private(set) var entries: [AppLogEntry] = []

    func log(_ message: String) {
        entries.append(AppLogEntry(message: message))
    }

    func clear() {
        entries.removeAll()
    }
}

struct AppLogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let message: String

    init(id: UUID = UUID(), date: Date = Date(), message: String) {
        self.id = id
        self.date = date
        self.message = message
    }
}
