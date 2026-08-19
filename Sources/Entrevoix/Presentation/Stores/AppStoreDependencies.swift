import Foundation
import EntrevoixCore

@MainActor
struct AppStoreDependencies {
    let coordinator: DictationCoordinator
    let connectionTest: ConnectionTestCoordinator
    let textDelivery: any TextDelivering
    let preferencesStore: any PreferencesStoring
    let keychain: any SecretStoring
    let codexCredentials: any CodexCredentialsStoring & CodexAccessTokenProviding
    let codexAuthenticator: any CodexAuthenticating
    let modelCatalog: any RemoteModelDiscovering
    let providerAlerts: any ProviderAlertPresenting
    let hotkeys: any HotkeyHandling
    let launchAtLogin: any LaunchAtLoginControlling
    let feedback: any FeedbackPlaying
    let listeningIndicator: any ListeningIndicatorPresenting
    let permissions: any PermissionProviding
    let updater: any ApplicationUpdating
    let logStore: AppLogStore
    let now: () -> Date

    init(
        coordinator: DictationCoordinator,
        connectionTest: ConnectionTestCoordinator,
        textDelivery: any TextDelivering,
        preferencesStore: any PreferencesStoring,
        keychain: any SecretStoring,
        codexCredentials: any CodexCredentialsStoring & CodexAccessTokenProviding = UnavailableCodexCredentialsStore(),
        codexAuthenticator: any CodexAuthenticating = UnavailableCodexAuthenticator(),
        modelCatalog: any RemoteModelDiscovering = UnavailableModelCatalog(),
        providerAlerts: any ProviderAlertPresenting = makeNoOpProviderAlertPresenter(),
        hotkeys: any HotkeyHandling,
        launchAtLogin: any LaunchAtLoginControlling,
        feedback: any FeedbackPlaying,
        listeningIndicator: any ListeningIndicatorPresenting,
        permissions: any PermissionProviding,
        updater: any ApplicationUpdating = UnavailableApplicationUpdater(),
        logStore: AppLogStore,
        now: @escaping () -> Date
    ) {
        self.coordinator = coordinator; self.connectionTest = connectionTest; self.textDelivery = textDelivery
        self.preferencesStore = preferencesStore; self.keychain = keychain; self.codexCredentials = codexCredentials; self.codexAuthenticator = codexAuthenticator; self.modelCatalog = modelCatalog; self.providerAlerts = providerAlerts
        self.hotkeys = hotkeys; self.launchAtLogin = launchAtLogin; self.feedback = feedback
        self.listeningIndicator = listeningIndicator; self.permissions = permissions; self.updater = updater; self.logStore = logStore
        self.now = now
    }
}

@MainActor
private final class UnavailableApplicationUpdater: ApplicationUpdating {
    func start(channel: UpdateChannel) {}
    func setChannel(_ channel: UpdateChannel) {}
    func checkForUpdates() {}
}

private actor UnavailableCodexCredentialsStore: CodexCredentialsStoring, CodexAccessTokenProviding {
    func readCodexCredentials() async throws -> CodexCredentials? { nil }
    func saveCodexCredentials(_ credentials: CodexCredentials?) async throws { throw UnavailableError() }
    func validCredentials() async throws -> CodexCredentials { throw UnavailableError() }
    private struct UnavailableError: Error {}
}

@MainActor
private final class UnavailableCodexAuthenticator: CodexAuthenticating {
    func connect() async throws -> CodexCredentials { throw UnavailableError() }
    private struct UnavailableError: Error {}
}

private struct UnavailableModelCatalog: RemoteModelDiscovering {
    func discoverModels(configuration: ProviderConfiguration, apiKey: String) async throws -> [String] { throw UnavailableError() }
    private struct UnavailableError: Error {}
}
