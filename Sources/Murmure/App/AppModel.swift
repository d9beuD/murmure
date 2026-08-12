import Foundation
import MurmureCore
import Observation

@MainActor
@Observable
final class AppModel {
    let coordinator: DictationCoordinator
    private let connectionTest: ConnectionTestModel
    private let hotkeys: any HotkeyHandling
    private let textDelivery: any TextDelivering
    private let preferencesStore: any PreferencesStoring
    private let launchAtLoginService: any LaunchAtLoginControlling
    private let soundFeedback: any FeedbackPlaying
    private let listeningIndicator: any ListeningIndicatorPresenting
    private let permissionProvider: any PermissionProviding
    private let keychain: any SecretStoring
    let logStore: AppLogStore

    private(set) var mode: TriggerMode
    var preferences: AppPreferences
    private(set) var interfaceLanguageRevision = 0
    var sttAPIKey = ""
    var cleanupAPIKey = ""
    var connectionTestState: ConnectionTestState { connectionTest.state }
    private var launchAtLoginErrorDetail: String?
    var launchAtLoginError: String? {
        guard let launchAtLoginErrorDetail else { return nil }
        let format = MurmureLocalization.text(
            "error.launch_at_login",
            defaultValue: "Could not change the launch at login setting: %@",
            locale: interfaceLocale
        )
        return String(format: format, locale: interfaceLocale, arguments: [launchAtLoginErrorDetail])
    }
    private(set) var permissionsRevision = 0
    var lastAudioURL: URL? { coordinator.lastAudioURL }

    var lastTranscript: String? { coordinator.lastTranscript }

    var interfaceLocale: Locale {
        _ = interfaceLanguageRevision
        return MurmureLocalization.locale(for: preferences.interfaceLanguage)
    }

    func setInterfaceLanguage(_ language: InterfaceLanguage) {
        guard preferences.interfaceLanguage != language else { return }
        preferences.interfaceLanguage = language
        interfaceLanguageRevision &+= 1
        savePreferences()
    }

    var cleanupPromptForDisplay: String {
        switch preferences.cleanupPromptMode {
        case .localizedDefault:
            MurmureLocalization.defaultCleanupPrompt(locale: interfaceLocale)
        case .custom, .legacyDefaultPendingChoice:
            preferences.cleanupPrompt
        }
    }

    var shouldOfferCleanupPromptMigration: Bool {
        preferences.cleanupPromptMode == .legacyDefaultPendingChoice
            && interfaceLocale.language.languageCode?.identifier == "fr"
    }

    private var globalShortcutIsDown = false
    private var lastShortcutEventAt: Date?
    private let now: () -> Date

    init(dependencies: AppDependencies) {
        coordinator = dependencies.coordinator
        connectionTest = dependencies.connectionTest
        hotkeys = dependencies.hotkeys
        textDelivery = dependencies.textDelivery
        logStore = dependencies.logStore
        preferencesStore = dependencies.preferencesStore
        keychain = dependencies.keychain
        launchAtLoginService = dependencies.launchAtLogin
        soundFeedback = dependencies.feedback
        listeningIndicator = dependencies.listeningIndicator
        permissionProvider = dependencies.permissions
        now = dependencies.now
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

        coordinator.onRecordingStarted = { [weak self] in
            guard let self else { return }
            self.listeningIndicator.show(label: MurmureLocalization.text(
                "dictation.listening",
                defaultValue: "Listening…",
                locale: self.interfaceLocale
            ))
            self.playFeedback(.recordingStarted)
        }

        coordinator.onRecordingStopped = { [weak self] in
            self?.playFeedback(.recordingStopped)
        }

        coordinator.onProcessingFinished = { [weak self] in
            self?.listeningIndicator.hide()
        }

        coordinator.onTextCleanupStarted = { [weak self] in
            guard let self else { return }
            self.listeningIndicator.update(label: MurmureLocalization.text(
                "dictation.improving",
                defaultValue: "Improving text…",
                locale: self.interfaceLocale
            ))
        }

        connectionTest.onEvent = { [weak self] event in
            switch event {
            case .recordingStarted:
                self?.refreshPermissions()
                self?.playFeedback(.recordingStarted)
            case .recordingStopped:
                self?.playFeedback(.recordingStopped)
            case .succeeded:
                self?.playFeedback(.connectionTestSucceeded)
            case .failed:
                self?.refreshPermissions()
                self?.playFeedback(.error)
            }
        }

        hotkeys.onKeyDown = { [weak self] in
            self?.handleKeyDown()
        }

        hotkeys.onKeyUp = { [weak self] in
            self?.handleKeyUp()
        }

        hotkeys.onEscape = { [weak self] in
            self?.handleEscape()
        }
    }

    func savePreferences() {
        preferencesStore.save(preferences)
        var secrets = [preferences.stt.id: sttAPIKey]
        secrets[preferences.cleanupProvider.id] = cleanupAPIKey
        try? keychain.save(secrets)
    }

    var requiresOnboarding: Bool { !preferences.hasCompletedOnboarding }

    var microphonePermission: PermissionStatus {
        _ = permissionsRevision
        return permissionProvider.microphonePermission
    }

    var accessibilityPermission: PermissionStatus {
        _ = permissionsRevision
        return permissionProvider.accessibilityPermission
    }

    var launchAtLoginEnabled: Bool {
        launchAtLoginService.isEnabled
    }

    func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
        savePreferences()
    }

    func requestMicrophonePermission() {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.permissionProvider.requestMicrophonePermission()
            self.refreshPermissions()
        }
    }

    func requestAccessibilityPermission() {
        permissionProvider.requestAccessibilityPermission()
        refreshPermissions()
        Task { [weak self] in
            for _ in 0..<30 {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.refreshPermissions()
                if self.accessibilityPermission == .granted { return }
            }
        }
    }

    func refreshPermissions() {
        permissionsRevision &+= 1
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            preferences.launchAtLogin = enabled
            launchAtLoginErrorDetail = nil
            savePreferences()
        } catch {
            launchAtLoginErrorDetail = error.localizedDescription
            logStore.log("Error: could not change the launch at login setting.")
        }
    }

    func resetCleanupPrompt() {
        preferences.cleanupPrompt = AppPreferences.defaultCleanupPrompt
        preferences.cleanupPromptMode = .localizedDefault
        savePreferences()
    }

    func acceptLocalizedCleanupPrompt() {
        preferences.cleanupPromptMode = .localizedDefault
        savePreferences()
    }

    func keepLegacyCleanupPrompt() {
        preferences.cleanupPromptMode = .custom
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
        let now = now()
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

    func handleEscape() {
        switch state {
        case .requestingPermission, .recording, .transcribing:
            cancelRecording()
        default:
            break
        }
    }

    func startRecording() {
        guard connectionTestState.isInactive else { return }
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
        guard state == .recording else { return }
        coordinator.stopRecording(request: DictationRequest(
            transcription: TranscriptionRequest(
                configuration: preferences.stt,
                apiKey: sttAPIKey,
                prompt: preferences.sttPrompt,
                language: preferences.sttLanguage
            ),
            cleanup: preferences.cleanupEnabled ? CleanupRequest(
                configuration: preferences.cleanupProvider,
                apiKey: cleanupAPIKey,
                format: preferences.cleanupFormat,
                prompt: cleanupPromptForDisplay,
                failurePolicy: preferences.cleanupFailurePolicy
            ) : nil,
            outputMode: preferences.outputMode
        ))
        if coordinator.state == .transcribing {
            listeningIndicator.update(label: MurmureLocalization.text(
                "dictation.transcribing",
                defaultValue: "Transcribing…",
                locale: interfaceLocale
            ))
        } else {
            listeningIndicator.hide()
        }
    }

    func cancelRecording() {
        listeningIndicator.hide()
        coordinator.cancelRecording()
    }

    func startSTTConnectionTest() {
        guard coordinator.state == .idle, connectionTestState.isInactive else { return }
        connectionTest.start()
    }

    func finishSTTConnectionTest() {
        connectionTest.finish(request: TranscriptionRequest(
            configuration: preferences.stt,
            apiKey: sttAPIKey,
            prompt: preferences.sttPrompt,
            language: preferences.sttLanguage
        ))
    }

    func cancelSTTConnectionTest() {
        connectionTest.cancel()
    }

    func copyTestText() {
        textDelivery.copy(MurmureLocalization.text("test.clipboard", defaultValue: "Murmure — clipboard test", locale: interfaceLocale))
    }

    func pasteTestText() {
        textDelivery.copyAndPaste(MurmureLocalization.text("test.insertion", defaultValue: "Murmure — insertion test", locale: interfaceLocale))
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

    private func playFeedback(_ event: FeedbackEvent) {
        guard preferences.playFeedbackSounds else { return }
        soundFeedback.play(event)
    }
}

enum PermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined
}
