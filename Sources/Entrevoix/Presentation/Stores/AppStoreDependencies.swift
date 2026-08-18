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
    let logStore: AppLogStore
    let now: () -> Date
    let sessionArbiter: (any SessionArbitrating)?

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
        logStore: AppLogStore,
        now: @escaping () -> Date,
        sessionArbiter: (any SessionArbitrating)?
    ) {
        self.coordinator = coordinator; self.connectionTest = connectionTest; self.textDelivery = textDelivery
        self.preferencesStore = preferencesStore; self.keychain = keychain; self.codexCredentials = codexCredentials; self.codexAuthenticator = codexAuthenticator; self.modelCatalog = modelCatalog; self.providerAlerts = providerAlerts
        self.hotkeys = hotkeys; self.launchAtLogin = launchAtLogin; self.feedback = feedback
        self.listeningIndicator = listeningIndicator; self.permissions = permissions; self.logStore = logStore
        self.now = now; self.sessionArbiter = sessionArbiter
    }
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
