import Foundation
import EntrevoixCore
import Observation

@MainActor
@Observable
final class AppStore {
    let dictationSession: DictationStore
    let connectionTestStore: ConnectionTestStore
    let preferencesModel: PreferencesStore
    let providerStore: ProviderStore
    let permissionsModel: PermissionsStore
    let promptLibrary: PromptLibraryStore
    var coordinator: DictationCoordinator { dictationSession.coordinator }
    private var connectionTest: ConnectionTestCoordinator { connectionTestStore.coordinator }
    private let hotkeys: any HotkeyHandling
    private let textDelivery: any TextDelivering
    private let launchAtLoginService: any LaunchAtLoginControlling
    private let soundFeedback: any FeedbackPlaying
    private let listeningIndicator: any ListeningIndicatorPresenting
    private let providerAlerts: any ProviderAlertPresenting
    let logStore: AppLogStore

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
    var connectionTestState: ConnectionTestState { connectionTestStore.state }
    var mode: TriggerMode { preferences.triggerMode }
    private var launchAtLoginErrorDetail: String?
    var launchAtLoginError: String? {
        guard let launchAtLoginErrorDetail else { return nil }
        let format = EntrevoixLocalization.text(
            "error.launch_at_login",
            defaultValue: "Could not change the launch at login setting: %@",
            locale: interfaceLocale
        )
        return String(format: format, locale: interfaceLocale, arguments: [launchAtLoginErrorDetail])
    }
    var permissionsRevision: Int { permissionsModel.revision }
    var isResettingMicrophonePermission: Bool { permissionsModel.isResettingMicrophonePermission }
    var microphonePermissionRepairFeedback: MicrophonePermissionRepairFeedback? {
        permissionsModel.microphonePermissionRepairFeedback
    }
    var lastAudioURL: URL? { dictationSession.lastAudioURL }

    var lastTranscript: String? { dictationSession.lastTranscript }
    var discoveredModels: [UUID: [String]] { providerStore.discoveredModels }
    var modelDiscoveryError: String? { providerStore.modelDiscoveryErrors.values.first }
    var codexConnectionState: CodexConnectionState { providerStore.codexConnectionState }

    var interfaceLocale: Locale {
        _ = interfaceLanguageRevision
        return EntrevoixLocalization.locale(for: preferences.interfaceLanguage)
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

    var providersSortedForDisplay: [ProviderCatalogEntry] {
        providerStore.providersSortedForDisplay
    }

    func providerName(_ entry: ProviderCatalogEntry) -> String {
        providerStore.providerName(entry)
    }

    func apiKey(for provider: ProviderIdentifier?) -> String { providerStore.apiKey(for: provider) }

    func setAPIKey(_ value: String, for provider: ProviderIdentifier?) {
        providerStore.setAPIKey(value, for: provider)
    }

    func setSTTProvider(_ id: ProviderIdentifier?) {
        providerStore.setSTTProvider(id)
    }

    func setTTTProvider(_ id: ProviderIdentifier?) {
        providerStore.setTTTProvider(id)
    }

    func addAppleProvider() {
        providerStore.addAppleProvider()
    }

    func addCodexProvider() {
        providerStore.addCodexProvider()
    }

    func setCodexModel(_ model: CodexModel) {
        providerStore.setCodexModel(model)
    }

    func connectCodex() {
        providerStore.connectCodex()
    }

    func disconnectCodex() {
        providerStore.disconnectCodex()
    }

    func removeCodexProvider() {
        providerStore.removeCodexProvider()
    }

    func newRemoteProvider(kind: RemoteProviderKind) -> RemoteProviderProfile {
        providerStore.newRemoteProvider(kind: kind)
    }

    @discardableResult
    func saveRemoteProvider(_ draft: RemoteProviderProfile, apiKey: String) -> [ProviderValidationIssue] {
        providerStore.saveRemoteProvider(draft, apiKey: apiKey)
    }

    @discardableResult
    func removeProvider(_ id: ProviderIdentifier) -> Bool {
        providerStore.removeProvider(id)
    }

    func loadModels(for profile: RemoteProviderProfile) {
        providerStore.loadModels(for: profile)
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

    init(dependencies: AppStoreDependencies, initialPreferences: AppPreferences) {
        dictationSession = DictationStore(coordinator: dependencies.coordinator)
        connectionTestStore = ConnectionTestStore(coordinator: dependencies.connectionTest)
        hotkeys = dependencies.hotkeys
        textDelivery = dependencies.textDelivery
        logStore = dependencies.logStore
        let preferencesModel = PreferencesStore(
            preferencesStore: dependencies.preferencesStore,
            keychain: dependencies.keychain,
            initialPreferences: initialPreferences
        )
        self.preferencesModel = preferencesModel
        providerStore = ProviderStore(
            preferencesStore: preferencesModel,
            modelCatalog: dependencies.modelCatalog,
            codexCredentialsStore: dependencies.codexCredentials,
            codexAuthenticator: dependencies.codexAuthenticator,
            logStore: dependencies.logStore
        )
        permissionsModel = PermissionsStore(provider: dependencies.permissions)
        promptLibrary = PromptLibraryStore(preferencesModel: preferencesModel)
        launchAtLoginService = dependencies.launchAtLogin
        soundFeedback = dependencies.feedback
        listeningIndicator = dependencies.listeningIndicator
        providerAlerts = dependencies.providerAlerts
        now = dependencies.now
        coordinator.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .recordingTimedOut:
                self.stopRecording()
            case .recordingStarted:
                self.listeningIndicator.show(label: EntrevoixLocalization.text(
                    "dictation.listening",
                    defaultValue: "Listening…",
                    locale: self.interfaceLocale
                ))
                self.playFeedback(.recordingStarted)
            case .recordingStopped:
                self.playFeedback(.recordingStopped)
                self.listeningIndicator.update(label: EntrevoixLocalization.text(
                    "dictation.transcribing",
                    defaultValue: "Transcribing…",
                    locale: self.interfaceLocale
                ))
            case .cleanupStarted:
                self.listeningIndicator.update(label: EntrevoixLocalization.text(
                    "dictation.improving",
                    defaultValue: "Improving text…",
                    locale: self.interfaceLocale
                ))
            case .providerUnavailable(let capability, let reason):
                self.logStore.log("Apple \(capability.rawValue) unavailable (\(reason.rawValue)).")
                self.providerAlerts.presentUnavailable(capability: capability, reason: reason)
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

    func resetMicrophonePermission() {
        permissionsModel.resetMicrophonePermission()
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

    var state: DictationState { dictationSession.state }

    func setMode(_ newMode: TriggerMode) {
        guard state == .idle else { return }
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
        guard let request = makeDictationRequest() else {
            logStore.log("Error: no usable STT provider is selected.")
            return
        }
        coordinator.startRecording(request: request)
    }

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    func stopRecording() {
        guard state == .recording else { return }
        guard let request = makeDictationRequest() else { return }
        coordinator.stopRecording(request: request)
    }

    func cancelRecording() {
        let shouldPlayCancellation = switch state {
        case .requestingPermission, .recording, .transcribing:
            true
        case .idle, .error:
            false
        }
        coordinator.cancelRecording()
        if shouldPlayCancellation {
            playFeedback(.recordingCancelled)
        }
    }

    func startSTTConnectionTest() {
        guard coordinator.state == .idle, connectionTestState.isInactive else { return }
        guard let transcription = makeTranscriptionRequest() else { return }
        connectionTest.start(request: transcription)
    }

    func finishSTTConnectionTest() {
        guard let transcription = makeTranscriptionRequest() else { return }
        connectionTest.finish(request: transcription)
    }

    func cancelSTTConnectionTest() {
        let shouldPlayCancellation = !connectionTestState.isInactive
        connectionTest.cancel()
        if shouldPlayCancellation {
            playFeedback(.recordingCancelled)
        }
    }

    func copyTestText() {
        textDelivery.copy(EntrevoixLocalization.text("test.clipboard", defaultValue: "Entrevoix — clipboard test", locale: interfaceLocale))
    }

    func pasteTestText() {
        textDelivery.copyAndPaste(EntrevoixLocalization.text("test.insertion", defaultValue: "Entrevoix — insertion test", locale: interfaceLocale))
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
            instructions: EntrevoixLocalization.defaultCleanupPrompt(locale: interfaceLocale)
        )
    }

    private static let defaultCleanupPromptName = "Standard"
    private static let defaultCleanupPromptIcon = "wand.and.stars"

    private func makeDictationRequest() -> DictationRequest? {
        providerStore.makeDictationRequest(activeCleanupPrompt: activeCleanupPrompt)
    }

    private func makeTranscriptionRequest() -> TranscriptionRequest? {
        providerStore.makeTranscriptionRequest()
    }
}
