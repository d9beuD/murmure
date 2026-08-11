import Foundation
import MurmureCore

@MainActor
enum CompositionRoot {
    static func makeAppModel() -> AppModel {
        let audioRecorder = AudioRecorder()
        let permissions = SystemPermissionProvider()
        let logStore = AppLogStore()
        let transport = SafeNetworkSession()
        let transcriber = OpenAITranscriptionService(transport: transport)
        let cleaner = OpenAITextCleanupService(transport: transport)
        let textDelivery = TextDelivery()

        let coordinator = DictationCoordinator(
            dependencies: DictationDependencies(
                audioRecorder: audioRecorder,
                microphonePermission: permissions,
                textDelivery: textDelivery,
                transcriber: transcriber,
                cleaner: cleaner,
                logger: logStore
            )
        )
        let connectionTest = ConnectionTestModel(
            audioRecorder: audioRecorder,
            microphonePermission: permissions,
            transcriber: transcriber,
            logger: logStore,
            now: Date.init
        )

        return AppModel(dependencies: AppDependencies(
            coordinator: coordinator,
            connectionTest: connectionTest,
            textDelivery: textDelivery,
            preferencesStore: UserDefaultsPreferencesStore(),
            keychain: KeychainStore(),
            hotkeys: HotkeyService(),
            launchAtLogin: LaunchAtLoginService(),
            feedback: SoundFeedback(),
            permissions: permissions,
            logStore: logStore,
            now: Date.init
        ))
    }
}
