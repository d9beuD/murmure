import EntrevoixCore
import Sparkle

@MainActor
final class SparkleUpdateService: NSObject, ApplicationUpdating, SPUUpdaterDelegate {
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )
    private var selectedChannel: UpdateChannel = .stable
    private var didStart = false

    func start(channel: UpdateChannel) {
        selectedChannel = channel
        guard !didStart else { return }
        didStart = true
        updaterController.startUpdater()
    }

    func setChannel(_ channel: UpdateChannel) {
        selectedChannel = channel
        guard didStart else { return }
        updaterController.updater.resetUpdateCycle()
    }

    func checkForUpdates() {
        if !didStart {
            start(channel: selectedChannel)
        }
        updaterController.updater.checkForUpdates()
    }

    static func allowedChannels(for channel: UpdateChannel) -> Set<String> {
        switch channel {
        case .stable:
            []
        case .releaseCandidate:
            ["rc"]
        case .development:
            ["dev", "rc"]
        }
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        Self.allowedChannels(for: selectedChannel)
    }
}
