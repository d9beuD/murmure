import EntrevoixCore
import XCTest
@testable import Entrevoix

final class SparkleUpdateServiceTests: XCTestCase {
    @MainActor
    func testSparkleChannelMappingPreservesStableAndProgressivePreReleaseChannels() {
        XCTAssertEqual(SparkleUpdateService.allowedChannels(for: .stable), [])
        XCTAssertEqual(SparkleUpdateService.allowedChannels(for: .releaseCandidate), ["rc"])
        XCTAssertEqual(SparkleUpdateService.allowedChannels(for: .development), ["dev", "rc"])
    }
}
