/// The composition-root result shared by all scenes. It owns references but no UI state.
@MainActor
final class AppEnvironment {
    let appStore: AppStore

    init(appStore: AppStore) {
        self.appStore = appStore
    }
}
