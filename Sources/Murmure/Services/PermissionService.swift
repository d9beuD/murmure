import ApplicationServices
import AVFoundation

@MainActor
protocol PermissionProviding: AnyObject {
    var microphonePermission: PermissionStatus { get }
    var accessibilityPermission: PermissionStatus { get }
    func requestAccessibilityPermission()
}

@MainActor
final class SystemPermissionProvider: PermissionProviding {
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
