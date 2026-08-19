import AVFoundation
import AudioToolbox
import EntrevoixCore
import Foundation
import Synchronization

@MainActor
protocol AudioLevelProviding: AnyObject {
    func updateMeters()
    var averagePower: Float { get }
}

/// Records a microphone session into the application's fixed PCM WAV format.
/// The engine is created per capture because voice processing can only be
/// enabled while it is stopped; ending the engine's I/O session restores the
/// other applications' audio before transcription begins.
@MainActor
final class AudioRecorder: AudioRecording, AudioLevelProviding {
    private var engine: AVAudioEngine?
    private var captureWriter: AudioCaptureWriter?
    private var hasInstalledTap = false
    private(set) var currentURL: URL?

    private let logger: any LogWriting

    init(logger: any LogWriting) {
        self.logger = logger
    }

    @discardableResult
    func start(
        input: AudioInputSelection,
        options: AudioRecordingOptions
    ) throws -> AudioInputStartResult {
        guard engine == nil else { return .requestedInput }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Entrevoix", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        switch input {
        case .systemDefault:
            try startCapture(at: url, deviceUID: nil, options: options)
            return .requestedInput
        case .device(let device):
            do {
                try startCapture(at: url, deviceUID: device.uid, options: options)
                return .requestedInput
            } catch {
                try? FileManager.default.removeItem(at: url)
                try startCapture(at: url, deviceUID: nil, options: options)
                return .fellBackToSystemDefault
            }
        }
    }

    private func startCapture(
        at url: URL,
        deviceUID: String?,
        options: AudioRecordingOptions
    ) throws {
        let newEngine = AVAudioEngine()
        let inputNode = newEngine.inputNode

        if options.duckOtherAudio {
            do {
                try inputNode.setVoiceProcessingEnabled(true)
                inputNode.voiceProcessingOtherAudioDuckingConfiguration = AudioDuckingConfiguration.maximum
            } catch {
                logger.log("Audio ducking unavailable; recording without audio ducking.")
            }
        }

        if let deviceUID {
            try setInputDevice(uid: deviceUID, on: inputNode)
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.couldNotStart
        }

        do {
            let writer = try AudioCaptureWriter(inputFormat: inputFormat, outputURL: url)
            inputNode.installTap(onBus: 0, bufferSize: 8_192, format: inputFormat) {
                buffer, _ in
                writer.append(buffer)
            }
            hasInstalledTap = true
            newEngine.prepare()
            try newEngine.start()
            engine = newEngine
            captureWriter = writer
            currentURL = url
        } catch {
            if hasInstalledTap {
                inputNode.removeTap(onBus: 0)
                hasInstalledTap = false
            }
            newEngine.stop()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private func setInputDevice(uid: String, on inputNode: AVAudioInputNode) throws {
        guard let deviceID = Self.deviceID(forUID: uid) else {
            throw RecorderError.inputDeviceUnavailable
        }
        guard let audioUnit = inputNode.audioUnit else {
            throw RecorderError.couldNotStart
        }

        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw RecorderError.audioDevice(status) }
    }

    private nonisolated static func deviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let value = uid as CFString
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafePointer(to: value) { pointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                pointer,
                &size,
                &deviceID
            )
        }
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    /// Metering is calculated as input buffers arrive; retaining this method
    /// preserves the listening indicator's existing abstraction.
    func updateMeters() {}

    var averagePower: Float {
        captureWriter?.averagePower ?? -160
    }

    func stop() -> URL? {
        let result = finishCapture()
        guard result == .success, let currentURL else { return nil }
        return currentURL
    }

    func cancel() {
        _ = finishCapture()
        if let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
        }
        currentURL = nil
    }

    func deleteLastCapture() {
        guard engine == nil, let currentURL else { return }
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

    private func finishCapture() -> AudioCaptureWriter.Result {
        guard let engine, let captureWriter else { return .empty }

        engine.stop()
        if hasInstalledTap {
            engine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        self.engine = nil
        self.captureWriter = nil

        let result = captureWriter.finish()
        if result != .success, let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
            self.currentURL = nil
        }
        return result
    }
}

/// Synchronizes the realtime engine callback with the main-actor lifecycle.
/// A mutex is necessary here because a tap callback is synchronous and cannot
/// await actor isolation without dispatching work for every audio buffer.
final class AudioCaptureWriter: Sendable {
    enum Result: Equatable {
        case success
        case empty
        case failed
    }

    private struct State {
        let converter: AVAudioConverter
        let file: AVAudioFile
        let outputFormat: AVAudioFormat
        var averagePower: Float = -160
        var didWriteFrames = false
        var didFail = false
        var isFinished = false
    }

    private let state: Mutex<State>

    init(inputFormat: AVAudioFormat, outputURL: URL) throws {
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw RecorderError.couldNotStart
        }
        converter.downmix = true

        let file = try AVAudioFile(
            forWriting: outputURL,
            settings: outputFormat.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
        state = Mutex(State(converter: converter, file: file, outputFormat: outputFormat))
    }

    var averagePower: Float {
        state.withLock { $0.averagePower }
    }

    func append(_ input: AVAudioPCMBuffer) {
        state.withLock { state in
            guard !state.isFinished, !state.didFail else { return }
            state.averagePower = Self.averagePower(for: input)

            let convertedFrameCount = max(
                Int(input.frameLength),
                Int((Double(input.frameLength) * state.outputFormat.sampleRate / input.format.sampleRate).rounded(.up)) + 32
            )
            guard let output = AVAudioPCMBuffer(
                pcmFormat: state.outputFormat,
                frameCapacity: AVAudioFrameCount(convertedFrameCount)
            ) else {
                state.didFail = true
                return
            }

            let source = ConverterInputBlockSource(input)
            var conversionError: NSError?
            let status = state.converter.convert(to: output, error: &conversionError) { _, inputStatus in
                source.next(into: inputStatus)
            }
            guard conversionError == nil, status != .error, output.frameLength > 0 else {
                state.didFail = true
                return
            }
            do {
                try state.file.write(from: output)
                state.didWriteFrames = true
            } catch {
                state.didFail = true
            }
        }
    }

    func finish() -> Result {
        state.withLock { state in
            guard !state.isFinished else {
                return state.didFail ? .failed : (state.didWriteFrames ? .success : .empty)
            }
            state.isFinished = true
            state.file.close()
            return state.didFail ? .failed : (state.didWriteFrames ? .success : .empty)
        }
    }

    private static func averagePower(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return -160 }

        var squaredSum: Float = 0
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                let sample = channels[channel][frame]
                squaredSum += sample * sample
            }
        }

        let sampleCount = Float(frameCount * channelCount)
        guard squaredSum > 0, sampleCount > 0 else { return -160 }
        return max(-160, 20 * log10(sqrt(squaredSum / sampleCount)))
    }
}

/// AVAudioConverter invokes this block synchronously while `AudioCaptureWriter`
/// holds its mutex. AVAudioPCMBuffer has no Sendable conformance, so this small
/// wrapper documents the externally synchronized Objective-C boundary rather
/// than leaking an unchecked conformance into the recorder itself.
private final class ConverterInputBlockSource: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private var hasProvidedBuffer = false

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(into status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard !hasProvidedBuffer else {
            status.pointee = .noDataNow
            return nil
        }
        hasProvidedBuffer = true
        status.pointee = .haveData
        return buffer
    }
}

enum AudioDuckingConfiguration {
    static let maximum = AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
        enableAdvancedDucking: false,
        duckingLevel: .max
    )
}

enum RecorderError: LocalizedError, LogSafeError, UserFacingErrorProviding {
    case couldNotStart
    case inputDeviceUnavailable
    case audioDevice(OSStatus)

    var errorDescription: String? {
        "Could not start recording. Check microphone permission."
    }

    var userFacingMessage: UserFacingErrorMessage {
        .recordingCouldNotStart
    }

    var logMessage: String {
        switch self {
        case .couldNotStart, .inputDeviceUnavailable:
            "Could not start recording."
        case .audioDevice(let status):
            "Core Audio input selection failed (OSStatus \(status))."
        }
    }
}
