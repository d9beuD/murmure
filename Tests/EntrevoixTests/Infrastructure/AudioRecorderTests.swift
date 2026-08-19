import AVFoundation
import EntrevoixCore
import XCTest
@testable import Entrevoix

@MainActor
final class AudioRecorderTests: XCTestCase {
    func testPrewarmedDuckingEngineIsReusedAcrossDictations() throws {
        let engine = AudioCaptureEngineSpy()
        let factory = AudioCaptureEngineFactorySpy(engines: [engine])
        let recorder = AudioRecorder(logger: AppLogStore(), captureEngineFactory: factory)

        recorder.prewarmDucking()

        XCTAssertEqual(factory.makeCount, 1)
        XCTAssertEqual(engine.enableDuckingCount, 1)
        XCTAssertEqual(engine.configuredInputs, [.systemDefault])
        XCTAssertEqual(engine.prepareForCaptureCount, 1)

        try recorder.start(
            input: .systemDefault,
            options: AudioRecordingOptions(duckOtherAudio: true)
        )
        recorder.cancel()
        try recorder.start(
            input: .systemDefault,
            options: AudioRecordingOptions(duckOtherAudio: true)
        )
        recorder.cancel()

        XCTAssertEqual(factory.makeCount, 1)
        XCTAssertEqual(engine.startCaptureCount, 2)
        XCTAssertEqual(engine.pauseCaptureCount, 2)
        XCTAssertEqual(engine.discardCount, 0)
    }

    func testStandardAndDuckingCapturesUseSeparateCachedEngines() throws {
        let standardEngine = AudioCaptureEngineSpy()
        let duckingEngine = AudioCaptureEngineSpy()
        let factory = AudioCaptureEngineFactorySpy(engines: [standardEngine, duckingEngine])
        let recorder = AudioRecorder(logger: AppLogStore(), captureEngineFactory: factory)

        try recorder.start(input: .systemDefault, options: .standard)
        recorder.cancel()
        recorder.prewarmDucking()
        try recorder.start(
            input: .systemDefault,
            options: AudioRecordingOptions(duckOtherAudio: true)
        )
        recorder.cancel()
        try recorder.start(input: .systemDefault, options: .standard)
        recorder.cancel()

        XCTAssertEqual(factory.makeCount, 2)
        XCTAssertEqual(standardEngine.enableDuckingCount, 0)
        XCTAssertEqual(standardEngine.startCaptureCount, 2)
        XCTAssertEqual(duckingEngine.enableDuckingCount, 1)
        XCTAssertEqual(duckingEngine.startCaptureCount, 1)
    }

    func testPrewarmingSelectedInputReusesItsDuckingEngine() throws {
        let engine = AudioCaptureEngineSpy()
        let factory = AudioCaptureEngineFactorySpy(engines: [engine])
        let recorder = AudioRecorder(logger: AppLogStore(), captureEngineFactory: factory)
        let selectedInput = AudioInputDeviceReference(uid: "external-mic", name: "External microphone")

        recorder.prewarmDucking(input: .device(selectedInput))
        try recorder.start(
            input: .device(selectedInput),
            options: AudioRecordingOptions(duckOtherAudio: true)
        )
        recorder.cancel()

        XCTAssertEqual(factory.makeCount, 1)
        XCTAssertEqual(engine.configuredInputs, [.device(selectedInput)])
        XCTAssertEqual(engine.enableDuckingCount, 1)
        XCTAssertEqual(engine.startCaptureCount, 1)
    }

    func testUnavailableSelectedInputDiscardsItsEngineAndFallsBackToSystemDefault() throws {
        let unavailableEngine = AudioCaptureEngineSpy(configureError: AppStubError.failure)
        let fallbackEngine = AudioCaptureEngineSpy()
        let factory = AudioCaptureEngineFactorySpy(engines: [unavailableEngine, fallbackEngine])
        let recorder = AudioRecorder(logger: AppLogStore(), captureEngineFactory: factory)
        let selectedInput = AudioInputDeviceReference(uid: "missing-device", name: "Missing microphone")

        let result = try recorder.start(input: .device(selectedInput), options: .standard)
        recorder.cancel()

        XCTAssertEqual(result, .fellBackToSystemDefault)
        XCTAssertEqual(unavailableEngine.configuredInputs, [.device(selectedInput)])
        XCTAssertEqual(unavailableEngine.discardCount, 1)
        XCTAssertEqual(fallbackEngine.configuredInputs, [.systemDefault])
        XCTAssertEqual(fallbackEngine.startCaptureCount, 1)
    }

    func testDuckingPrewarmFailureFallsBackWithoutBlockingCapture() throws {
        let engine = AudioCaptureEngineSpy(enableDuckingError: AppStubError.failure)
        let factory = AudioCaptureEngineFactorySpy(engines: [engine])
        let recorder = AudioRecorder(logger: AppLogStore(), captureEngineFactory: factory)

        recorder.prewarmDucking()
        try recorder.start(
            input: .systemDefault,
            options: AudioRecordingOptions(duckOtherAudio: true)
        )
        recorder.cancel()

        XCTAssertEqual(factory.makeCount, 1)
        XCTAssertEqual(engine.enableDuckingCount, 1)
        XCTAssertEqual(engine.startCaptureCount, 1)
    }

    func testFailedCaptureEvictsTheCachedEngineBeforeRetrying() throws {
        let failedEngine = AudioCaptureEngineSpy(startCaptureError: AppStubError.failure)
        let replacementEngine = AudioCaptureEngineSpy()
        let factory = AudioCaptureEngineFactorySpy(engines: [failedEngine, replacementEngine])
        let recorder = AudioRecorder(logger: AppLogStore(), captureEngineFactory: factory)

        recorder.prewarmDucking()
        XCTAssertThrowsError(try recorder.start(
            input: .systemDefault,
            options: AudioRecordingOptions(duckOtherAudio: true)
        ))
        try recorder.start(
            input: .systemDefault,
            options: AudioRecordingOptions(duckOtherAudio: true)
        )
        recorder.cancel()

        XCTAssertEqual(failedEngine.discardCount, 1)
        XCTAssertEqual(factory.makeCount, 2)
        XCTAssertEqual(replacementEngine.enableDuckingCount, 1)
        XCTAssertEqual(replacementEngine.startCaptureCount, 1)
    }

    func testCaptureTapRunsOutsideTheMainActor() throws {
        let inputFormat = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        ))
        let url = try appTemporaryFile()
        try FileManager.default.removeItem(at: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AudioCaptureWriter(inputFormat: inputFormat, outputURL: url)
        let tap = LiveAudioCaptureEngine.makeCaptureTap(writer: writer)

        let audioQueue = DispatchQueue(label: "AudioRecorderTests.captureTap")
        let completed = expectation(description: "Capture tap completed")
        audioQueue.async {
            dispatchPrecondition(condition: .onQueue(audioQueue))
            dispatchPrecondition(condition: .notOnQueue(.main))
            guard let callbackFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 48_000,
                channels: 1,
                interleaved: false
            ), let buffer = AVAudioPCMBuffer(pcmFormat: callbackFormat, frameCapacity: 480) else {
                XCTFail("Expected a valid callback buffer")
                completed.fulfill()
                return
            }
            buffer.frameLength = 480
            tap(buffer, AVAudioTime())
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)

        XCTAssertEqual(writer.finish(), .success)
    }

    func testCaptureWriterConvertsStereoFloatInputToRequiredWAVFormatAndMetersIt() throws {
        let inputFormat = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 2,
            interleaved: false
        ))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 480))
        buffer.frameLength = 480
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<2 {
            for frame in 0..<480 {
                channels[channel][frame] = 0.5
            }
        }

        let url = try appTemporaryFile()
        try FileManager.default.removeItem(at: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AudioCaptureWriter(inputFormat: inputFormat, outputURL: url)

        writer.append(buffer)

        XCTAssertEqual(writer.averagePower, -6.02, accuracy: 0.05)
        XCTAssertEqual(writer.finish(), .success)

        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.sampleRate, 16_000)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(file.fileFormat.streamDescription.pointee.mBitsPerChannel, 16)
        XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatLinearPCM)
        XCTAssertGreaterThan(file.length, 0)
    }

    func testCaptureWriterPreservesSignalOutsideFirstChannelWhenDownmixing() throws {
        let layoutTag = AudioChannelLayoutTag(kAudioChannelLayoutTag_DiscreteInOrder) | 6
        let channelLayout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: layoutTag))
        let inputFormat = AVAudioFormat(
            standardFormatWithSampleRate: 48_000,
            channelLayout: channelLayout
        )
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 480))
        buffer.frameLength = 480
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for frame in 0..<480 {
            channels[5][frame] = 0.5
        }

        let url = try appTemporaryFile()
        try FileManager.default.removeItem(at: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AudioCaptureWriter(inputFormat: inputFormat, outputURL: url)

        writer.append(buffer)

        XCTAssertEqual(writer.finish(), .success)
        let file = try AVAudioFile(forReading: url)
        let output = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ))
        try file.read(into: output)
        let samples = try XCTUnwrap(output.floatChannelData?.pointee)
        let maximum = (0..<Int(output.frameLength)).reduce(Float.zero) { maximum, frame in
            max(maximum, abs(samples[frame]))
        }
        XCTAssertGreaterThan(maximum, 0.01)
    }

    func testMaximumDuckingIsContinuous() {
        XCTAssertFalse(AudioDuckingConfiguration.maximum.enableAdvancedDucking.boolValue)
        XCTAssertEqual(AudioDuckingConfiguration.maximum.duckingLevel, .max)
    }
}

@MainActor
private final class AudioCaptureEngineFactorySpy: AudioCaptureEngineFactory {
    private var engines: [AudioCaptureEngineSpy]
    private(set) var makeCount = 0

    init(engines: [AudioCaptureEngineSpy]) {
        self.engines = engines
    }

    func makeCaptureEngine() -> any AudioCaptureEngine {
        makeCount += 1
        guard !engines.isEmpty else {
            fatalError("AudioCaptureEngineFactorySpy requires an engine for every creation.")
        }
        return engines.removeFirst()
    }
}

@MainActor
private final class AudioCaptureEngineSpy: AudioCaptureEngine {
    let inputFormat: AVAudioFormat
    let enableDuckingError: (any Error)?
    let configureError: (any Error)?
    let startCaptureError: (any Error)?

    private(set) var enableDuckingCount = 0
    private(set) var configuredInputs: [AudioInputSelection] = []
    private(set) var prepareForCaptureCount = 0
    private(set) var startCaptureCount = 0
    private(set) var pauseCaptureCount = 0
    private(set) var discardCount = 0

    init(
        inputFormat: AVAudioFormat? = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        ),
        enableDuckingError: (any Error)? = nil,
        configureError: (any Error)? = nil,
        startCaptureError: (any Error)? = nil
    ) {
        self.inputFormat = inputFormat ?? AVAudioFormat()
        self.enableDuckingError = enableDuckingError
        self.configureError = configureError
        self.startCaptureError = startCaptureError
    }

    func enableDucking() throws {
        enableDuckingCount += 1
        if let enableDuckingError { throw enableDuckingError }
    }

    func configure(input: AudioInputSelection) throws {
        configuredInputs.append(input)
        if let configureError { throw configureError }
    }

    func prepareForCapture() {
        prepareForCaptureCount += 1
    }

    func startCapture(writer: AudioCaptureWriter) throws {
        startCaptureCount += 1
        if let startCaptureError { throw startCaptureError }
    }

    func pauseCapture() {
        pauseCaptureCount += 1
    }

    func discard() {
        discardCount += 1
    }
}
