import AVFoundation
import Foundation
import MurmureCore

@MainActor
protocol AudioLevelProviding: AnyObject {
    func updateMeters()
    var averagePower: Float { get }
}

@MainActor
final class AudioRecorder: AudioRecording, AudioLevelProviding {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?

    func start() throws {
        guard recorder == nil else { return }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Murmure", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.prepareToRecord()
        newRecorder.isMeteringEnabled = true

        guard newRecorder.record() else {
            throw RecorderError.couldNotStart
        }

        recorder = newRecorder
        currentURL = url
    }

    func updateMeters() {
        recorder?.updateMeters()
    }

    var averagePower: Float {
        recorder?.averagePower(forChannel: 0) ?? -160
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        return currentURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil

        if let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
        }

        currentURL = nil
    }

    func deleteLastCapture() {
        guard let currentURL else { return }
        try? FileManager.default.removeItem(at: currentURL)
        self.currentURL = nil
    }

    func captureSize(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    func deleteCapture(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        if currentURL == url { currentURL = nil }
    }
}

enum RecorderError: LocalizedError, LogSafeError, UserFacingErrorProviding {
    case couldNotStart

    var errorDescription: String? {
        "Could not start recording. Check microphone permission."
    }

    var userFacingMessage: UserFacingErrorMessage {
        .recordingCouldNotStart
    }

    var logMessage: String { "Could not start recording." }
}
