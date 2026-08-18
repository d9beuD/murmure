import Foundation
import EntrevoixCore

@MainActor
enum CompositionRoot {
    enum LaunchState {
        case ready(AppEnvironment, recoveredPreferences: Bool)
        case incompatible(schemaVersion: Int)
    }

    static func makeLaunchState() -> LaunchState {
        LegacyMurmureMigration.run()
        let preferencesStore = UserDefaultsPreferencesStore()
        var loadedPreferences: AppPreferences
        let recovered: Bool

        switch preferencesStore.load() {
        case .loaded(let preferences):
            loadedPreferences = preferences
            recovered = false
        case .recovered(let preferences):
            loadedPreferences = preferences
            recovered = true
        case .incompatible(let schemaVersion):
            return .incompatible(schemaVersion: schemaVersion)
        }

        let migratedPreferences = PreferencesMigrator.migrate(
            loadedPreferences,
            localizedDefaultPrompt: EntrevoixLocalization.defaultCleanupPrompt(
                locale: EntrevoixLocalization.locale(for: loadedPreferences.interfaceLanguage)
            )
        )
        if migratedPreferences != loadedPreferences {
            preferencesStore.save(migratedPreferences)
            loadedPreferences = migratedPreferences
        }

        return .ready(
            makeEnvironment(preferencesStore: preferencesStore, initialPreferences: loadedPreferences),
            recoveredPreferences: recovered
        )
    }

    private static func makeEnvironment(
        preferencesStore: UserDefaultsPreferencesStore,
        initialPreferences: AppPreferences
    ) -> AppEnvironment {
        let audioRecorder = AudioRecorder()
        let permissions = SystemPermissionProvider()
        let logStore = AppLogStore()
        let transport = SafeNetworkSession()
        let codexCredentials = CodexCredentialVault()
        let speechResources = AppleSpeechResourceManager()
        let transcriber = ProviderSpeechRouter(
            remote: OpenAITranscriptionService(transport: transport),
            apple: AppleSpeechTranscriptionService(resources: speechResources)
        )
        let cleaner = ProviderCleanupRouter(
            remote: OpenAITextCleanupService(transport: transport),
            codex: CodexCleanupService(
                transport: transport,
                credentialsProvider: codexCredentials
            ),
            apple: AppleFoundationCleanupService()
        )
        let textDelivery = TextDelivery()
        let sessionArbiter = SessionArbiter()

        let coordinator = DictationCoordinator(
            dependencies: DictationDependencies(
                audioRecorder: audioRecorder,
                microphonePermission: permissions,
                textDelivery: textDelivery,
                transcriber: transcriber,
                cleaner: cleaner,
                logger: logStore,
                sessionArbiter: sessionArbiter
            )
        )
        let connectionTest = ConnectionTestCoordinator(
            audioRecorder: audioRecorder,
            microphonePermission: permissions,
            transcriber: transcriber,
            logger: logStore,
            now: Date.init,
            sessionArbiter: sessionArbiter
        )

        let appStore = AppStore(dependencies: AppStoreDependencies(
            coordinator: coordinator,
            connectionTest: connectionTest,
            textDelivery: textDelivery,
            preferencesStore: preferencesStore,
            keychain: KeychainStore(legacyService: LegacyMurmureMigration.legacyKeychainService),
            codexCredentials: codexCredentials,
            codexAuthenticator: CodexBrowserAuthenticator(),
            modelCatalog: RemoteModelCatalogClient(transport: transport),
            providerAlerts: QueuedProviderAlertPresenter(),
            hotkeys: HotkeyService(),
            launchAtLogin: LaunchAtLoginService(),
            feedback: SoundFeedback(),
            listeningIndicator: ListeningIndicatorController(
                audioLevelProvider: audioRecorder,
                logger: logStore
            ),
            permissions: permissions,
            logStore: logStore,
            now: Date.init,
            sessionArbiter: sessionArbiter
        ), initialPreferences: initialPreferences)
        return AppEnvironment(appStore: appStore)
    }
}
