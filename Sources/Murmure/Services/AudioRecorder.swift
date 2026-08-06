import AVFoundation
import Foundation
import MurmureCore

@MainActor
final class AudioRecorder: AudioRecording {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?

    func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

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

        guard newRecorder.record() else {
            throw RecorderError.couldNotStart
        }

        recorder = newRecorder
        currentURL = url
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
}

enum RecorderError: LocalizedError, LogSafeError {
    case couldNotStart

    var errorDescription: String? {
        "Impossible de démarrer l’enregistrement. Vérifiez l’autorisation microphone."
    }

    var logMessage: String { "Impossible de démarrer l’enregistrement." }
}
