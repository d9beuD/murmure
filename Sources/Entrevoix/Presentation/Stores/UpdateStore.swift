import EntrevoixCore
import Observation

@MainActor
@Observable
final class UpdateStore {
    private let preferencesModel: PreferencesStore
    private let updater: any ApplicationUpdating

    private(set) var pendingChannel: UpdateChannel?
    var isConfirmationPresented = false

    var selectedChannel: UpdateChannel {
        preferencesModel.preferences.updateChannel
    }

    init(
        preferencesModel: PreferencesStore,
        updater: any ApplicationUpdating
    ) {
        self.preferencesModel = preferencesModel
        self.updater = updater
        updater.start(channel: preferencesModel.preferences.updateChannel)
    }

    func requestChannel(_ channel: UpdateChannel) {
        guard channel != selectedChannel else { return }
        if channel.requiresConfirmation(beforeChangingFrom: selectedChannel) {
            pendingChannel = channel
            isConfirmationPresented = true
        } else {
            apply(channel)
        }
    }

    func confirmPendingChannelChange() {
        guard let pendingChannel else {
            isConfirmationPresented = false
            return
        }
        apply(pendingChannel)
        self.pendingChannel = nil
        isConfirmationPresented = false
    }

    func cancelPendingChannelChange() {
        pendingChannel = nil
        isConfirmationPresented = false
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }

    private func apply(_ channel: UpdateChannel) {
        var preferences = preferencesModel.preferences
        preferences.updateChannel = channel
        preferencesModel.update(preferences, to: .immediate)
        updater.setChannel(channel)
    }
}
