import Foundation
import MurmureCore
import Observation

@MainActor
@Observable
final class AppModel {
    let coordinator: DictationCoordinator
    let hotkeys: HotkeyService
    private let textDelivery: any TextDelivering
    private let preferencesStore: any PreferencesStoring
    let keychain: KeychainStore

    var mode: TriggerMode = .pushToTalk
    var preferences: AppPreferences
    var sttAPIKey = ""
    var cleanupAPIKey = ""
    private(set) var lastAudioURL: URL?

    private var globalShortcutIsDown = false

    init(
        environment: AppEnvironment,
        preferencesStore: any PreferencesStoring = UserDefaultsPreferencesStore(),
        keychain: KeychainStore = KeychainStore()
    ) {
        coordinator = DictationCoordinator(environment: environment)
        hotkeys = HotkeyService()
        textDelivery = environment.textDelivery
        self.preferencesStore = preferencesStore
        self.keychain = keychain
        preferences = preferencesStore.preferences
        sttAPIKey = (try? keychain.read(profileID: preferences.stt.id)) ?? ""
        cleanupAPIKey = (try? keychain.read(profileID: preferences.cleanupProvider.id)) ?? ""

        hotkeys.onKeyDown = { [weak self] in
            self?.handleKeyDown()
        }

        hotkeys.onKeyUp = { [weak self] in
            self?.handleKeyUp()
        }
    }

    func savePreferences() {
        preferencesStore.save(preferences)
        try? keychain.save(sttAPIKey, profileID: preferences.stt.id)
        try? keychain.save(cleanupAPIKey, profileID: preferences.cleanupProvider.id)
    }

    func resetCleanupPrompt() {
        preferences.cleanupPrompt = AppPreferences.defaultCleanupPrompt
        savePreferences()
    }

    var state: DictationState { coordinator.state }

    func handleKeyDown() {
        guard !globalShortcutIsDown else { return }
        globalShortcutIsDown = true

        switch mode {
        case .pushToTalk:
            coordinator.startRecording()
        case .toggle:
            if state == .recording {
                stopRecording()
            } else {
                startRecording()
            }
        }
    }

    func handleKeyUp() {
        globalShortcutIsDown = false

        if mode == .pushToTalk, state == .recording {
            stopRecording()
        }
    }

    func startRecording() {
        coordinator.startRecording()
    }

    func stopRecording() {
        coordinator.stopRecording()
        lastAudioURL = coordinator.lastAudioURL
    }

    func cancelRecording() {
        coordinator.cancelRecording()
        lastAudioURL = nil
    }

    func copyTestText() {
        textDelivery.copy("Murmure — test presse-papiers")
    }

    func pasteTestText() {
        textDelivery.copyAndPaste("Murmure — test insertion")
    }

    func deleteLastCapture() {
        coordinator.deleteLastCapture()
        lastAudioURL = nil
    }
}
