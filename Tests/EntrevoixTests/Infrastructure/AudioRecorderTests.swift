import AVFoundation
import XCTest
@testable import Entrevoix

final class AudioRecorderTests: XCTestCase {
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
