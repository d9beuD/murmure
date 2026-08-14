import EntrevoixCore

/// The composition-root result shared by all scenes. It owns references but no UI state.
@MainActor
final class AppEnvironment {
    let appStore: AppStore
    let dictationCoordinator: DictationCoordinator
    let connectionTestCoordinator: ConnectionTestCoordinator

    init(
        appStore: AppStore,
        dictationCoordinator: DictationCoordinator,
        connectionTestCoordinator: ConnectionTestCoordinator
    ) {
        self.appStore = appStore
        self.dictationCoordinator = dictationCoordinator
        self.connectionTestCoordinator = connectionTestCoordinator
    }
}
