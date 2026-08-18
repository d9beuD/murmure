import Foundation
import XCTest
import EntrevoixCore
@testable import Entrevoix

@MainActor
final class PermissionServiceTests: XCTestCase {
    func testResetUsesOnlyEntrevoixMicrophoneTCCCommand() async throws {
        let runner = MicrophonePermissionResetCommandSpy()
        let provider = SystemPermissionProvider(microphonePermissionResetter: runner)

        try await provider.resetMicrophonePermission()

        XCTAssertEqual(runner.executablePath, "/usr/bin/tccutil")
        XCTAssertEqual(runner.arguments, ["reset", "Microphone", "com.d9beuD.Entrevoix"])
    }

    func testResetPropagatesCommandFailureWithoutProviderDetails() async {
        let runner = MicrophonePermissionResetCommandSpy(error: .commandFailed)
        let provider = SystemPermissionProvider(microphonePermissionResetter: runner)

        do {
            try await provider.resetMicrophonePermission()
            XCTFail("Expected the reset to fail")
        } catch let error {
            XCTAssertEqual(error, .commandFailed)
        }
    }
}

@MainActor
private final class MicrophonePermissionResetCommandSpy: MicrophonePermissionResetCommandRunning {
    let error: MicrophonePermissionResetError?
    private(set) var executablePath: String?
    private(set) var arguments: [String]?

    init(error: MicrophonePermissionResetError? = nil) {
        self.error = error
    }

    func run(
        executablePath: String,
        arguments: [String]
    ) async throws(MicrophonePermissionResetError) {
        self.executablePath = executablePath
        self.arguments = arguments
        if let error {
            throw error
        }
    }
}
