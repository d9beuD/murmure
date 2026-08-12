import XCTest
@testable import Murmure

final class ListeningIndicatorTests: XCTestCase {
    func testNormalizesAndClipsDecibelRange() {
        XCTAssertEqual(
            ListeningIndicatorAudioLevelSmoother.normalizedLevel(from: -100),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ListeningIndicatorAudioLevelSmoother.normalizedLevel(from: -64),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ListeningIndicatorAudioLevelSmoother.normalizedLevel(from: -35),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ListeningIndicatorAudioLevelSmoother.normalizedLevel(from: -6),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ListeningIndicatorAudioLevelSmoother.normalizedLevel(from: 0),
            1,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ListeningIndicatorAudioLevelSmoother.normalizedLevel(from: .nan),
            0,
            accuracy: 0.0001
        )
    }

    func testUsesFasterAttackAndSlowerRelease() {
        var smoother = ListeningIndicatorAudioLevelSmoother()

        XCTAssertEqual(smoother.update(decibels: -6), 0.65, accuracy: 0.0001)
        XCTAssertEqual(smoother.update(decibels: -6), 0.8775, accuracy: 0.0001)

        smoother.reset()
        _ = smoother.update(decibels: -6)
        XCTAssertEqual(smoother.update(decibels: -64), 0.4875, accuracy: 0.0001)
    }

    func testResetReturnsToSilentLevel() {
        var smoother = ListeningIndicatorAudioLevelSmoother()
        _ = smoother.update(decibels: -6)

        smoother.reset()

        XCTAssertEqual(smoother.level, 0, accuracy: 0.0001)
    }
}
