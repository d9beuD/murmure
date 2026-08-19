import Foundation

public struct AudioRecordingOptions: Equatable, Sendable {
    public let duckOtherAudio: Bool

    public init(duckOtherAudio: Bool = false) {
        self.duckOtherAudio = duckOtherAudio
    }

    public static let standard = AudioRecordingOptions()
}

@MainActor
public protocol AudioRecording: AnyObject {
    @discardableResult
    func start(
        input: AudioInputSelection,
        options: AudioRecordingOptions
    ) throws -> AudioInputStartResult
    func stop() -> URL?
    func cancel()
    func deleteLastCapture()
    func captureSize(at url: URL) -> Int
    func deleteCapture(at url: URL)
}
