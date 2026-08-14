import AppKit
import XCTest
@testable import Entrevoix

final class DockPresenceControllerTests: XCTestCase {
    @MainActor
    func testShowsDockForFirstWindowAndHidesItAfterLastWindowCloses() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockPresenceController { policy in
            policies.append(policy)
            return true
        }
        let settingsWindow = NSObject()
        let onboardingWindow = NSObject()

        controller.register(windowID: ObjectIdentifier(settingsWindow))
        XCTAssertTrue(controller.isDockVisible)
        XCTAssertEqual(policies, [.regular])

        controller.register(windowID: ObjectIdentifier(onboardingWindow))
        controller.unregister(windowID: ObjectIdentifier(settingsWindow))
        XCTAssertTrue(controller.isDockVisible)
        XCTAssertEqual(policies, [.regular])

        controller.unregister(windowID: ObjectIdentifier(onboardingWindow))
        XCTAssertFalse(controller.isDockVisible)
        XCTAssertEqual(policies, [.regular, .accessory])
    }

    @MainActor
    func testRepeatedRegistrationAndUnregistrationAreIdempotent() {
        var policies: [NSApplication.ActivationPolicy] = []
        let controller = DockPresenceController { policy in
            policies.append(policy)
            return true
        }
        let window = NSObject()
        let windowID = ObjectIdentifier(window)

        controller.register(windowID: windowID)
        controller.register(windowID: windowID)
        controller.unregister(windowID: windowID)
        controller.unregister(windowID: windowID)

        XCTAssertEqual(policies, [.regular, .accessory])
        XCTAssertFalse(controller.isDockVisible)
    }
}
