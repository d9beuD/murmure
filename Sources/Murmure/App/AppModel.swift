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
    let logStore: AppLogStore

    private(set) var mode: TriggerMode
    var preferences: AppPreferences
    var sttAPIKey = ""
    var cleanupAPIKey = ""
    var lastAudioURL: URL? { coordinator.lastAudioURL }

    var lastTranscript: String? { coordinator.lastTranscript }

    private var globalShortcutIsDown = false
    private var lastShortcutEventAt: Date?

    init(
        environment: AppEnvironment,
        preferencesStore: any PreferencesStoring = UserDefaultsPreferencesStore(),
        keychain: KeychainStore = KeychainStore()
    ) {
        coordinator = DictationCoordinator(environment: environment)
        hotkeys = HotkeyService()
        textDelivery = environment.textDelivery
        logStore = environment.logStore
        self.preferencesStore = preferencesStore
        self.keychain = keychain
        let storedPreferences = preferencesStore.preferences
        preferences = storedPreferences
        mode = storedPreferences.triggerMode
        let secrets = (try? keychain.read(profileIDs: [
            storedPreferences.stt.id,
            storedPreferences.cleanupProvider.id
        ])) ?? [:]
        sttAPIKey = secrets[storedPreferences.stt.id] ?? ""
        cleanupAPIKey = secrets[storedPreferences.cleanupProvider.id] ?? ""

        coordinator.onRecordingTimeout = { [weak self] in
            self?.stopRecording()
        }

        hotkeys.onKeyDown = { [weak self] in
            self?.handleKeyDown()
        }

        hotkeys.onKeyUp = { [weak self] in
            self?.handleKeyUp()
        }
    }

    func savePreferences() {
        preferencesStore.save(preferences)
        var secrets = [preferences.stt.id: sttAPIKey]
        secrets[preferences.cleanupProvider.id] = cleanupAPIKey
        try? keychain.save(secrets)
    }

    func resetCleanupPrompt() {
        preferences.cleanupPrompt = AppPreferences.defaultCleanupPrompt
        savePreferences()
    }

    var state: DictationState { coordinator.state }

    func setMode(_ newMode: TriggerMode) {
        guard state == .idle else { return }
        mode = newMode
        preferences.triggerMode = newMode
        savePreferences()
    }

    func handleKeyDown() {
        guard !globalShortcutIsDown else { return }
        let now = Date()
        if let lastShortcutEventAt, now.timeIntervalSince(lastShortcutEventAt) < DictationTiming.shortcutDebounce {
            return
        }
        lastShortcutEventAt = now
        globalShortcutIsDown = true

        switch mode {
        case .pushToTalk:
            startRecording()
        case .toggle:
            if state == .recording {
                stopRecording()
            } else if state == .idle || isErrorState {
                startRecording()
            }
        }
    }

    func handleKeyUp() {
        globalShortcutIsDown = false

        if mode == .pushToTalk {
            switch state {
            case .recording:
                stopRecording()
            case .requestingPermission:
                cancelRecording()
            default:
                break
            }
        }
    }

    func startRecording() {
        if isErrorState {
            coordinator.dismissError()
        }
        coordinator.startRecording()
    }

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    func stopRecording() {
        coordinator.stopRecording(
            configuration: preferences.stt,
            apiKey: sttAPIKey,
            prompt: preferences.sttPrompt,
            language: preferences.sttLanguage,
            cleanupEnabled: preferences.cleanupEnabled,
            cleanupConfiguration: preferences.cleanupProvider,
            cleanupAPIKey: cleanupAPIKey,
            cleanupFormat: preferences.cleanupFormat,
            cleanupPrompt: preferences.cleanupPrompt,
            cleanupFailurePolicy: preferences.cleanupFailurePolicy,
            outputMode: preferences.outputMode
        )
    }

    func cancelRecording() {
        coordinator.cancelRecording()
    }

    func copyTestText() {
        textDelivery.copy("Murmure — test presse-papiers")
    }

    func pasteTestText() {
        textDelivery.copyAndPaste("Murmure — test insertion")
    }

    func deleteLastCapture() {
        coordinator.deleteLastCapture()
    }

    func copyTranscript() {
        guard let lastTranscript else { return }
        textDelivery.copy(lastTranscript)
    }

    func deliverTranscript() {
        guard let lastTranscript else { return }
        if preferences.outputMode == .paste {
            textDelivery.copyAndPaste(lastTranscript)
        } else {
            textDelivery.copy(lastTranscript)
        }
    }
}
