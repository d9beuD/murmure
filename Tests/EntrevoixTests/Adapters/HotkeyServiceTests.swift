import XCTest
@testable import Entrevoix

final class HotkeyServiceTests: XCTestCase {
    func testPrimaryAndSecondaryShortcutsEachEmitAnIndependentPressCycle() {
        var state = DictationShortcutPressState()

        XCTAssertTrue(state.handleKeyDown(for: .primary))
        XCTAssertTrue(state.handleKeyUp(for: .primary))
        XCTAssertTrue(state.handleKeyDown(for: .secondary))
        XCTAssertTrue(state.handleKeyUp(for: .secondary))
    }

    func testRepeatedPressesAndOverlappingShortcutsEmitOnlyFirstDownAndLastUp() {
        var state = DictationShortcutPressState()

        XCTAssertTrue(state.handleKeyDown(for: .primary))
        XCTAssertFalse(state.handleKeyDown(for: .primary))
        XCTAssertFalse(state.handleKeyDown(for: .secondary))
        XCTAssertFalse(state.handleKeyUp(for: .primary))
        XCTAssertTrue(state.handleKeyUp(for: .secondary))
        XCTAssertFalse(state.handleKeyUp(for: .secondary))
    }

    func testMatchingPrimaryAndSecondaryShortcutEventsProduceOnePressCycle() {
        var state = DictationShortcutPressState()

        XCTAssertTrue(state.handleKeyDown(for: .primary))
        XCTAssertFalse(state.handleKeyDown(for: .secondary))
        XCTAssertFalse(state.handleKeyUp(for: .primary))
        XCTAssertTrue(state.handleKeyUp(for: .secondary))
    }
}
