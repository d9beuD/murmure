import Foundation
import EntrevoixCore
import Observation

@MainActor
@Observable
final class PermissionsStore {
    private let provider: any PermissionProviding
    private(set) var revision = 0
    private var accessibilityPollingTask: Task<Void, Never>?

    init(provider: any PermissionProviding) {
        self.provider = provider
    }

    var microphonePermission: PermissionStatus {
        _ = revision
        return provider.microphonePermission
    }

    var accessibilityPermission: PermissionStatus {
        _ = revision
        return provider.accessibilityPermission
    }

    func requestMicrophonePermission() {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.provider.requestMicrophonePermission()
            self.refresh()
        }
    }

    func requestAccessibilityPermission() {
        provider.requestAccessibilityPermission()
        refresh()
        accessibilityPollingTask?.cancel()
        accessibilityPollingTask = Task { [weak self] in
            for _ in 0..<30 {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self else { return }
                self.refresh()
                if self.accessibilityPermission == .granted { return }
            }
        }
    }

    func refresh() {
        revision &+= 1
    }
}
