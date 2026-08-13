import ApplicationServices
import AVFoundation
import MurmureCore

@MainActor
protocol PermissionProviding: MicrophonePermissionRequesting {
    var microphonePermission: PermissionStatus { get }
    var accessibilityPermission: PermissionStatus { get }
    func requestAccessibilityPermission()
}

@MainActor
final class SystemPermissionProvider: PermissionProviding {
    func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
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
