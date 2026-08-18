import ApplicationServices
import AVFoundation
import Foundation
import EntrevoixCore

@MainActor
protocol MicrophonePermissionResetCommandRunning: AnyObject {
    func run(
        executablePath: String,
        arguments: [String]
    ) async throws(MicrophonePermissionResetError)
}

@MainActor
final class SystemMicrophonePermissionResetter: MicrophonePermissionResetCommandRunning {
    func run(
        executablePath: String,
        arguments: [String]
    ) async throws(MicrophonePermissionResetError) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        do {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: MicrophonePermissionResetError.commandFailed)
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: MicrophonePermissionResetError.couldNotLaunch)
                }
            }
        } catch let error as MicrophonePermissionResetError {
            throw error
        } catch {
            throw .commandFailed
        }
    }
}

@MainActor
final class SystemPermissionProvider: PermissionProviding {
    static let microphonePermissionResetExecutablePath = "/usr/bin/tccutil"
    static let microphonePermissionResetArguments = ["reset", "Microphone", "com.d9beuD.Entrevoix"]

    private let microphonePermissionResetter: any MicrophonePermissionResetCommandRunning

    init(
        microphonePermissionResetter: any MicrophonePermissionResetCommandRunning = SystemMicrophonePermissionResetter()
    ) {
        self.microphonePermissionResetter = microphonePermissionResetter
    }

    func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied, .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func resetMicrophonePermission() async throws(MicrophonePermissionResetError) {
        try await microphonePermissionResetter.run(
            executablePath: Self.microphonePermissionResetExecutablePath,
            arguments: Self.microphonePermissionResetArguments
        )
    }

    var microphonePermission: PermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: .granted
        case .denied: .denied
        case .undetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    var accessibilityPermission: PermissionStatus {
        AXIsProcessTrusted() ? .granted : .notDetermined
    }

    func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions([
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary)
    }
}
