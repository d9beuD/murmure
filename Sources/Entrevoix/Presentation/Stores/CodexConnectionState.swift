import Foundation

enum CodexConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed
}
