import Foundation
import MurmureCore
import Observation

@MainActor
@Observable
final class AppModel {
    let dictationSession: DictationSessionModel
    let preferencesModel: PreferencesModel
    let permissionsModel: PermissionsModel
    let promptLibrary: PromptLibraryModel
    var coordinator: DictationCoordinator { dictationSession.coordinator }
    private let connectionTest: ConnectionTestModel
    private let hotkeys: any HotkeyHandling
    private let textDelivery: any TextDelivering
    private let launchAtLoginService: any LaunchAtLoginControlling
    private let soundFeedback: any FeedbackPlaying
    private let listeningIndicator: any ListeningIndicatorPresenting
    let logStore: AppLogStore

    private(set) var mode: TriggerMode
    var preferences: AppPreferences {
        get { preferencesModel.preferences }
        set { preferencesModel.update(newValue) }
    }
    private(set) var interfaceLanguageRevision = 0
    var sttAPIKey: String {
        get { preferencesModel.sttAPIKey }
        set { preferencesModel.updateSTTAPIKey(newValue) }
    }
    var cleanupAPIKey: String {
        get { preferencesModel.cleanupAPIKey }
        set { preferencesModel.updateCleanupAPIKey(newValue) }
    }
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
    var permissionsRevision: Int { permissionsModel.revision }
    var lastAudioURL: URL? { coordinator.lastAudioURL }

    var lastTranscript: String? { coordinator.lastTranscript }

    var interfaceLocale: Locale {
        _ = interfaceLanguageRevision
        return MurmureLocalization.locale(for: preferences.interfaceLanguage)
    }

    var activeCleanupPrompt: CleanupPrompt? {
        promptLibrary.activePrompt
    }

    var hasActiveCleanupPrompt: Bool { activeCleanupPrompt != nil }

    var cleanupPromptLibraryDiffersFromDefault: Bool {
        promptLibrary.differsFromDefault
    }

    func setInterfaceLanguage(_ language: InterfaceLanguage) {
        guard preferences.interfaceLanguage != language else { return }
        preferences.interfaceLanguage = language
        interfaceLanguageRevision &+= 1
        savePreferences()
    }

    func setSTTLanguage(_ language: TranscriptionLanguage) {
        var changed = preferences.sttLanguage != language
        preferences.sttLanguage = language
        if language != .automatic && !preferences.sttFavoriteLanguages.contains(language) {
            preferences.sttFavoriteLanguages.append(language)
            changed = true
        }
        if changed {
            savePreferences()
        }
    }

    func setSTTFavoriteLanguage(_ language: TranscriptionLanguage, enabled: Bool) {
        guard language != .automatic else { return }
        if enabled {
            guard !preferences.sttFavoriteLanguages.contains(language) else { return }
            preferences.sttFavoriteLanguages.append(language)
        } else {
            guard preferences.sttLanguage != language,
                  let index = preferences.sttFavoriteLanguages.firstIndex(of: language) else { return }
            preferences.sttFavoriteLanguages.remove(at: index)
        }
        savePreferences()
    }

    @discardableResult
    func addDictationDictionaryTerm(_ rawTerm: String) -> Bool {
        guard let term = AppPreferences.normalizedDictationDictionary([rawTerm]).first,
              !preferences.dictationDictionary.contains(term) else { return false }
        preferences.dictationDictionary.append(term)
        savePreferences()
        return true
    }

    func removeDictationDictionaryTerm(_ term: String) {
        guard let index = preferences.dictationDictionary.firstIndex(of: term) else { return }
        preferences.dictationDictionary.remove(at: index)
        savePreferences()
    }

    var cleanupPromptForDisplay: String { activeCleanupPrompt?.instructions ?? "" }

    private var globalShortcutIsDown = false
    private var lastShortcutEventAt: Date?
    private let now: () -> Date

    init(dependencies: AppDependencies, initialPreferences: AppPreferences) {
        dictationSession = DictationSessionModel(
            coordinator: dependencies.coordinator,
            connectionTest: dependencies.connectionTest
        )
        connectionTest = dependencies.connectionTest
        hotkeys = dependencies.hotkeys
        textDelivery = dependencies.textDelivery
        logStore = dependencies.logStore
        preferencesModel = PreferencesModel(
            preferencesStore: dependencies.preferencesStore,
            keychain: dependencies.keychain,
            initialPreferences: initialPreferences
        )
        permissionsModel = PermissionsModel(provider: dependencies.permissions)
        promptLibrary = PromptLibraryModel(preferencesModel: preferencesModel)
        launchAtLoginService = dependencies.launchAtLogin
        soundFeedback = dependencies.feedback
        listeningIndicator = dependencies.listeningIndicator
        now = dependencies.now
        mode = initialPreferences.triggerMode
        coordinator.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .recordingTimedOut:
                self.stopRecording()
            case .recordingStarted:
                self.listeningIndicator.show(label: MurmureLocalization.text(
                    "dictation.listening",
                    defaultValue: "Listening…",
                    locale: self.interfaceLocale
                ))
                self.playFeedback(.recordingStarted)
            case .recordingStopped:
                self.playFeedback(.recordingStopped)
                self.listeningIndicator.update(label: MurmureLocalization.text(
                    "dictation.transcribing",
                    defaultValue: "Transcribing…",
                    locale: self.interfaceLocale
                ))
            case .cleanupStarted:
                self.listeningIndicator.update(label: MurmureLocalization.text(
                    "dictation.improving",
                    defaultValue: "Improving text…",
                    locale: self.interfaceLocale
                ))
            case .sessionEnded:
                self.listeningIndicator.hide()
            }
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
        preferencesModel.flushPendingWrites()
    }

    var requiresOnboarding: Bool { !preferences.hasCompletedOnboarding }

    var microphonePermission: PermissionStatus {
        permissionsModel.microphonePermission
    }

    var accessibilityPermission: PermissionStatus {
        permissionsModel.accessibilityPermission
    }

    var launchAtLoginEnabled: Bool {
        launchAtLoginService.isEnabled
    }

    func completeOnboarding() {
        preferences.hasCompletedOnboarding = true
        savePreferences()
    }

    func requestMicrophonePermission() {
        permissionsModel.requestMicrophonePermission()
    }

    func requestAccessibilityPermission() {
        permissionsModel.requestAccessibilityPermission()
    }

    func refreshPermissions() {
        permissionsModel.refresh()
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

    func setActiveCleanupPrompt(_ id: UUID?) {
        promptLibrary.setActive(id)
    }

    @discardableResult
    func saveCleanupPrompt(_ prompt: CleanupPrompt) -> CleanupPromptValidationError? {
        promptLibrary.save(prompt)
    }

    func deleteCleanupPrompt(id: UUID) {
        promptLibrary.delete(id: id)
    }

    func resetPromptLibrary() {
        promptLibrary.reset()
    }

    func resetCleanupPrompt() { resetPromptLibrary() }

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
                prompt: preferences.dictationDictionaryPrompt,
                language: preferences.sttLanguage.apiCode
            ),
            cleanup: preferences.cleanupEnabled ? activeCleanupPrompt.map {
                CleanupRequest(
                    configuration: preferences.cleanupProvider,
                    apiKey: cleanupAPIKey,
                    format: preferences.cleanupFormat,
                    prompt: $0.instructions,
                    failurePolicy: preferences.cleanupFailurePolicy
                )
            } : nil,
            outputMode: preferences.outputMode
        ))
    }

    func cancelRecording() {
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
            prompt: preferences.dictationDictionaryPrompt,
            language: preferences.sttLanguage.apiCode
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

    private func defaultCleanupPromptDefinition() -> CleanupPrompt {
        CleanupPrompt(
            name: Self.defaultCleanupPromptName,
            systemImageName: Self.defaultCleanupPromptIcon,
            instructions: MurmureLocalization.defaultCleanupPrompt(locale: interfaceLocale)
        )
    }

    private static let defaultCleanupPromptName = "Standard"
    private static let defaultCleanupPromptIcon = "wand.and.stars"
}

enum CleanupPromptValidationError: Error, Equatable {
    case emptyName
    case duplicateName
    case emptyInstructions
    case invalidIcon
}

enum PermissionStatus: Equatable {
    case granted
    case denied
    case notDetermined
}
