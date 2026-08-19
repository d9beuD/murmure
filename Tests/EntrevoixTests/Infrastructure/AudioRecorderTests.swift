import AVFoundation
import XCTest
@testable import Entrevoix

final class AudioRecorderTests: XCTestCase {
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
        let tap = AudioRecorder.makeCaptureTap(writer: writer)

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

    func testMaximumDuckingIsContinuous() {
        XCTAssertFalse(AudioDuckingConfiguration.maximum.enableAdvancedDucking.boolValue)
        XCTAssertEqual(AudioDuckingConfiguration.maximum.duckingLevel, .max)
    }
}
