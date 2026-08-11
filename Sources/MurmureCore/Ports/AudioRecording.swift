import Foundation

@MainActor
public protocol AudioRecording: AnyObject {
    func start() throws
    func stop() -> URL?
    func cancel()
    func deleteLastCapture()
}
