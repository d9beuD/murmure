import Foundation
import EntrevoixCore

@MainActor
struct AppStoreDependencies {
    let coordinator: DictationCoordinator
    let connectionTest: ConnectionTestCoordinator
    let textDelivery: any TextDelivering
    let preferencesStore: any PreferencesStoring
    let keychain: any SecretStoring
    let modelCatalog: any RemoteModelDiscovering
    let providerAlerts: any ProviderAlertPresenting
    let hotkeys: any HotkeyHandling
    let launchAtLogin: any LaunchAtLoginControlling
    let feedback: any FeedbackPlaying
    let listeningIndicator: any ListeningIndicatorPresenting
    let permissions: any PermissionProviding
    let logStore: AppLogStore
    let now: () -> Date
    let sessionArbiter: (any SessionArbitrating)?

    init(
        coordinator: DictationCoordinator,
        connectionTest: ConnectionTestCoordinator,
        textDelivery: any TextDelivering,
        preferencesStore: any PreferencesStoring,
        keychain: any SecretStoring,
        modelCatalog: any RemoteModelDiscovering = UnavailableModelCatalog(),
        providerAlerts: any ProviderAlertPresenting = makeNoOpProviderAlertPresenter(),
        hotkeys: any HotkeyHandling,
        launchAtLogin: any LaunchAtLoginControlling,
        feedback: any FeedbackPlaying,
        listeningIndicator: any ListeningIndicatorPresenting,
        permissions: any PermissionProviding,
        logStore: AppLogStore,
        now: @escaping () -> Date,
        sessionArbiter: (any SessionArbitrating)?
    ) {
        self.coordinator = coordinator; self.connectionTest = connectionTest; self.textDelivery = textDelivery
        self.preferencesStore = preferencesStore; self.keychain = keychain; self.modelCatalog = modelCatalog; self.providerAlerts = providerAlerts
        self.hotkeys = hotkeys; self.launchAtLogin = launchAtLogin; self.feedback = feedback
        self.listeningIndicator = listeningIndicator; self.permissions = permissions; self.logStore = logStore
        self.now = now; self.sessionArbiter = sessionArbiter
    }
}

private struct UnavailableModelCatalog: RemoteModelDiscovering {
    func discoverModels(configuration: ProviderConfiguration, apiKey: String) async throws -> [String] { throw UnavailableError() }
    private struct UnavailableError: Error {}
}
