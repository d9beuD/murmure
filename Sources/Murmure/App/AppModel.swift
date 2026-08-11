import Foundation
import MurmureCore
import Observation

@MainActor
@Observable
final class AppModel {
    let coordinator: DictationCoordinator
    private let hotkeys: any HotkeyHandling
    private let textDelivery: any TextDelivering
    private let preferencesStore: any PreferencesStoring
    private let testAudioRecorder: any AudioRecording
    private let transcriber: any SpeechTranscribing
    private let launchAtLoginService: any LaunchAtLoginControlling
    private let soundFeedback: any FeedbackPlaying
    private let permissionProvider: any PermissionProviding
    private let now: () -> Date
    private let keychain: any SecretStoring
    let logStore: AppLogStore

    private(set) var mode: TriggerMode
    var preferences: AppPreferences
    var sttAPIKey = ""
    var cleanupAPIKey = ""
    var connectionTestState: ConnectionTestState = .idle
    var launchAtLoginError: String?
    private(set) var permissionsRevision = 0
    var lastAudioURL: URL? { coordinator.lastAudioURL }

    var lastTranscript: String? { coordinator.lastTranscript }

    private var globalShortcutIsDown = false
    private var lastShortcutEventAt: Date?
    private var connectionTestSessionID: UUID?
    private var connectionTestStartedAt: Date?
    private var connectionTestTask: Task<Void, Never>?

    init(
        environment: AppEnvironment,
        preferencesStore: any PreferencesStoring = UserDefaultsPreferencesStore(),
        keychain: any SecretStoring = KeychainStore(),
        hotkeys: any HotkeyHandling = HotkeyService(),
        launchAtLoginService: any LaunchAtLoginControlling = LaunchAtLoginService(),
        soundFeedback: any FeedbackPlaying = SoundFeedback(),
        permissionProvider: any PermissionProviding = SystemPermissionProvider(),
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        coordinator = DictationCoordinator(environment: environment, now: now, sleep: sleep)
        self.hotkeys = hotkeys
        textDelivery = environment.textDelivery
        testAudioRecorder = environment.audioRecorder
        transcriber = environment.transcriber
        logStore = environment.logStore
        self.preferencesStore = preferencesStore
        self.keychain = keychain
        self.launchAtLoginService = launchAtLoginService
        self.soundFeedback = soundFeedback
        self.permissionProvider = permissionProvider
        self.now = now
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
            self?.playFeedback(.recordingStarted)
        }

        coordinator.onRecordingStopped = { [weak self] in
            self?.playFeedback(.recordingStopped)
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
            _ = await self.testAudioRecorder.requestPermission()
            self.refreshPermissions()
        }
    }

    func requestAccessibilityPermission() {
        permissionProvider.requestAccessibilityPermission()
        refreshPermissions()
    }

    func refreshPermissions() {
        permissionsRevision &+= 1
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            preferences.launchAtLogin = enabled
            launchAtLoginError = nil
            savePreferences()
        } catch {
            launchAtLoginError = "Could not change the launch at login setting: \(error.localizedDescription)"
            logStore.log("Error: could not change the launch at login setting.")
        }
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

    func startSTTConnectionTest() {
        guard coordinator.state == .idle, connectionTestState.isInactive else { return }
        let sessionID = UUID()
        connectionTestSessionID = sessionID
        connectionTestState = .requestingPermission
        Task { [weak self] in
            guard let self else { return }
            let granted = await self.testAudioRecorder.requestPermission()
            guard self.connectionTestSessionID == sessionID else { return }
            self.refreshPermissions()
            guard granted else {
                self.connectionTestSessionID = nil
                self.connectionTestState = .failed("Microphone access was denied. Allow Murmure in System Settings.")
                self.playFeedback(.error)
                return
            }
            do {
                try self.testAudioRecorder.start()
                self.connectionTestStartedAt = self.now()
                self.connectionTestState = .recording
                self.logStore.log("Connection test recording started")
                self.playFeedback(.recordingStarted)
            } catch {
                self.connectionTestSessionID = nil
                self.connectionTestState = .failed(error.localizedDescription)
                self.logStore.log("Error: connection test: \(safeLogMessage(for: error))")
                self.playFeedback(.error)
            }
        }
    }

    func finishSTTConnectionTest() {
        guard case .recording = connectionTestState, let sessionID = connectionTestSessionID else { return }
        let duration = connectionTestStartedAt.map { now().timeIntervalSince($0) } ?? 0
        connectionTestStartedAt = nil
        guard duration >= DictationTiming.minimumRecordingDuration, let audioURL = testAudioRecorder.stop() else {
            testAudioRecorder.cancel()
            connectionTestSessionID = nil
            connectionTestState = .failed("Record at least one short phrase before running the test.")
            return
        }
        connectionTestState = .testing
        logStore.log("Connection test recording ended")
        playFeedback(.recordingStopped)
        connectionTestTask?.cancel()
        connectionTestTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.testAudioRecorder.deleteLastCapture()
                if self.connectionTestSessionID == sessionID {
                    self.connectionTestSessionID = nil
                }
            }
            do {
                let host = self.preferences.stt.endpointURL?.host ?? "configured endpoint"
                self.logStore.log("Testing STT connection with \(host)")
                let text = try await self.transcriber.transcribe(
                    audioURL: audioURL,
                    configuration: self.preferences.stt,
                    apiKey: self.sttAPIKey,
                    prompt: self.preferences.sttPrompt,
                    language: self.preferences.sttLanguage
                )
                guard self.connectionTestSessionID == sessionID else { return }
                self.connectionTestState = .succeeded(characterCount: text.count)
                self.logStore.log("STT connection test succeeded (\(text.count) chars)")
                self.playFeedback(.connectionTestSucceeded)
            } catch is CancellationError {
                guard self.connectionTestSessionID == sessionID else { return }
                self.connectionTestState = .idle
            } catch {
                guard self.connectionTestSessionID == sessionID else { return }
                self.connectionTestState = .failed(error.localizedDescription)
                self.logStore.log("Error: connection test: \(safeLogMessage(for: error))")
                self.playFeedback(.error)
            }
        }
    }

    func cancelSTTConnectionTest() {
        connectionTestSessionID = nil
        connectionTestTask?.cancel()
        connectionTestTask = nil
        connectionTestStartedAt = nil
        testAudioRecorder.cancel()
        connectionTestState = .idle
    }

    func copyTestText() {
        textDelivery.copy("Murmure — clipboard test")
    }

    func pasteTestText() {
        textDelivery.copyAndPaste("Murmure — insertion test")
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

    var title: String {
        switch self {
        case .granted: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not allowed yet"
        }
    }
}

enum ConnectionTestState: Equatable {
    case idle
    case requestingPermission
    case recording
    case testing
    case succeeded(characterCount: Int)
    case failed(String)

    var isInactive: Bool {
        switch self {
        case .idle, .succeeded, .failed: true
        case .requestingPermission, .recording, .testing: false
        }
    }

    var title: String {
        switch self {
        case .idle: "Ready to test the STT connection."
        case .requestingPermission: "Requesting microphone access…"
        case .recording: "Recording test audio…"
        case .testing: "Sending the recording to the provider…"
        case .succeeded(let characterCount): "Connection verified: received \(characterCount) characters."
        case .failed(let message): message
        }
    }
}
