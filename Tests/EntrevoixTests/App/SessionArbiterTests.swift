import XCTest
import EntrevoixCore
@testable import Entrevoix

final class SessionArbiterTests: XCTestCase {
    @MainActor
    func testOnlyOneLeaseIsActiveAndStaleReleaseIsIgnored() throws {
        let arbiter = SessionArbiter()
        let first = try XCTUnwrap(arbiter.acquire(.dictation))
        XCTAssertNil(arbiter.acquire(.connectionTest))
        arbiter.release(SessionLease(kind: .dictation))
        XCTAssertNil(arbiter.acquire(.connectionTest))
        arbiter.release(first)
        XCTAssertNotNil(arbiter.acquire(.connectionTest))
    }
}
