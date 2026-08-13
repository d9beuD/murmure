import Foundation
import MurmureCore

@MainActor
enum CompositionRoot {
    enum LaunchState {
        case ready(AppModel, recoveredPreferences: Bool)
        case incompatible(schemaVersion: Int)
    }

    static func makeLaunchState() -> LaunchState {
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
            localizedDefaultPrompt: MurmureLocalization.defaultCleanupPrompt(
                locale: MurmureLocalization.locale(for: loadedPreferences.interfaceLanguage)
            )
        )
        if migratedPreferences != loadedPreferences {
            preferencesStore.save(migratedPreferences)
            loadedPreferences = migratedPreferences
        }

        return .ready(
            makeAppModel(preferencesStore: preferencesStore, initialPreferences: loadedPreferences),
            recoveredPreferences: recovered
        )
    }

    private static func makeAppModel(
        preferencesStore: UserDefaultsPreferencesStore,
        initialPreferences: AppPreferences
    ) -> AppModel {
        let audioRecorder = AudioRecorder()
        let permissions = SystemPermissionProvider()
        let logStore = AppLogStore()
        let transport = SafeNetworkSession()
        let transcriber = OpenAITranscriptionService(transport: transport)
        let cleaner = OpenAITextCleanupService(transport: transport)
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
        let connectionTest = ConnectionTestModel(
            audioRecorder: audioRecorder,
            microphonePermission: permissions,
            transcriber: transcriber,
            logger: logStore,
            now: Date.init,
            sessionArbiter: sessionArbiter
        )

        return AppModel(dependencies: AppDependencies(
            coordinator: coordinator,
            connectionTest: connectionTest,
            textDelivery: textDelivery,
            preferencesStore: preferencesStore,
            keychain: KeychainStore(),
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
    }
}
