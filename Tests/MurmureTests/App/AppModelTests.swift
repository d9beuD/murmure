import Foundation
import XCTest
import MurmureCore
@testable import Murmure

final class AppModelTests: XCTestCase {
    @MainActor
    func testLoadsAndSavesPreferencesAndSecrets() {
        var preferences = AppPreferences()
        preferences.sttLanguage = "fr"
        preferences.triggerMode = .toggle
        let secrets = [
            preferences.stt.id: "stt-key",
            preferences.cleanupProvider.id: "cleanup-key"
        ]
        let context = makeContext(preferences: preferences, secrets: secrets)

        XCTAssertEqual(context.model.preferences.sttLanguage, "fr")
        XCTAssertEqual(context.model.mode, .toggle)
        XCTAssertEqual(context.model.sttAPIKey, "stt-key")
        XCTAssertEqual(context.model.cleanupAPIKey, "cleanup-key")
        XCTAssertEqual(Set(context.secretStore.readIDs), Set(secrets.keys))

        context.model.preferences.sttLanguage = "en"
        context.model.sttAPIKey = "new-stt"
        context.model.cleanupAPIKey = "new-cleanup"
        context.model.savePreferences()

        XCTAssertEqual(context.preferencesStore.saved.last?.sttLanguage, "en")
        XCTAssertEqual(context.secretStore.saves.last?[preferences.stt.id], "new-stt")
        XCTAssertEqual(context.secretStore.saves.last?[preferences.cleanupProvider.id], "new-cleanup")
    }

    @MainActor
    func testChangingInterfaceLanguageUpdatesLocaleAndPersistsImmediately() {
        let context = makeContext(preferences: AppPreferences(interfaceLanguage: .english))

        XCTAssertEqual(context.model.interfaceLocale.identifier, "en")
        context.model.setInterfaceLanguage(.french)

        XCTAssertEqual(context.model.interfaceLocale.identifier, "fr-FR")
        XCTAssertEqual(context.preferencesStore.saved.last?.interfaceLanguage, .french)

        context.model.setInterfaceLanguage(.english)
        XCTAssertEqual(context.model.interfaceLocale.identifier, "en")
        XCTAssertEqual(context.preferencesStore.saved.last?.interfaceLanguage, .english)
    }

    @MainActor
    func testOnboardingPromptModeAndStateTitles() {
        var preferences = AppPreferences()
        preferences.cleanupPrompt = "custom"
        let context = makeContext(preferences: preferences)

        XCTAssertTrue(context.model.requiresOnboarding)
        context.model.completeOnboarding()
        XCTAssertFalse(context.model.requiresOnboarding)
        XCTAssertTrue(context.preferencesStore.saved.last?.hasCompletedOnboarding == true)

        context.model.resetCleanupPrompt()
        XCTAssertEqual(context.model.preferences.cleanupPrompt, AppPreferences.defaultCleanupPrompt)
        context.model.setMode(.toggle)
        XCTAssertEqual(context.model.mode, .toggle)
        XCTAssertEqual(context.model.preferences.triggerMode, .toggle)

        XCTAssertEqual(PermissionStatus.granted.title, "Allowed")
        XCTAssertEqual(PermissionStatus.denied.title, "Denied")
        XCTAssertEqual(PermissionStatus.notDetermined.title, "Not allowed yet")
        XCTAssertEqual(AuthenticationMode.allCases.map(\.title), ["Bearer", "API Key", "None"])
        XCTAssertEqual(CleanupAPIFormat.allCases.map(\.title), ["Responses API", "Chat Completions"])
        XCTAssertEqual(CleanupFailurePolicy.allCases.map(\.title), ["Use Raw Transcript", "Stop with an Error"])
        XCTAssertEqual(TriggerMode.allCases.map(\.title), ["Hold to Talk", "Press to Start/Stop"])
        XCTAssertEqual(OutputMode.allCases.map(\.title), ["Clipboard", "Insert Automatically"])
        XCTAssertEqual(DictationState.error(.audioUnavailable).title, "No audio file was produced.")
        XCTAssertTrue(ConnectionTestState.idle.isInactive)
        XCTAssertFalse(ConnectionTestState.testing.isInactive)
        XCTAssertEqual(ConnectionTestState.succeeded(characterCount: 12).title, "Connection verified: received 12 characters.")
        XCTAssertEqual(ConnectionTestState.failed(.transcriptionFailed(message: "failure")).title, "failure")
    }

    @MainActor
    func testPromptLibraryCRUDValidationAndReset() {
        let preferences = AppPreferences(interfaceLanguage: .french)
        let context = makeContext(preferences: preferences)
        XCTAssertEqual(context.model.activeCleanupPrompt?.instructions, MurmureLocalization.defaultCleanupPrompt(locale: context.model.interfaceLocale))

        let duplicate = CleanupPrompt(name: " Standard ", systemImageName: "sparkles", instructions: "Different")
        XCTAssertEqual(context.model.saveCleanupPrompt(duplicate), .duplicateName)
        let invalid = CleanupPrompt(name: "New", systemImageName: "circle", instructions: "Text")
        XCTAssertEqual(context.model.saveCleanupPrompt(invalid), .invalidIcon)

        let custom = CleanupPrompt(name: " Writing ", systemImageName: "quote.bubble", instructions: "Improve prose.")
        XCTAssertNil(context.model.saveCleanupPrompt(custom))
        XCTAssertEqual(context.model.preferences.cleanupPrompts.last?.name, "Writing")
        context.model.setActiveCleanupPrompt(custom.id)
        XCTAssertEqual(context.model.activeCleanupPrompt?.id, custom.id)
        context.model.deleteCleanupPrompt(id: custom.id)
        XCTAssertNil(context.model.preferences.cleanupPrompts.first { $0.id == custom.id })

        let standardID = context.model.preferences.cleanupPrompts[0].id
        context.model.deleteCleanupPrompt(id: standardID)
        XCTAssertTrue(context.model.preferences.cleanupPrompts.isEmpty)
        XCTAssertNil(context.model.preferences.activeCleanupPromptID)
        context.model.resetPromptLibrary()
        XCTAssertEqual(context.model.preferences.cleanupPrompts.count, 1)
        XCTAssertNotNil(context.model.activeCleanupPrompt)
    }

    @MainActor
    func testInvalidActivePromptReferenceIsRepairedAndPersisted() {
        var preferences = AppPreferences()
        preferences.activeCleanupPromptID = UUID()
        let context = makeContext(preferences: preferences)

        XCTAssertEqual(context.model.preferences.activeCleanupPromptID, context.model.preferences.cleanupPrompts.first?.id)
        XCTAssertEqual(context.preferencesStore.saved.last?.activeCleanupPromptID, context.model.preferences.activeCleanupPromptID)
    }

    @MainActor
    func testPushToTalkHandlesRepeatDebounceAndKeyUp() async throws {
        let recorder = AppRecorderSpy()
        let context = makeContext(recorder: recorder)

        context.hotkeys.onKeyDown?()
        await appWaitUntil("recording") { context.model.state == .recording }
        context.hotkeys.onKeyDown?()
        XCTAssertEqual(recorder.startCount, 1)
        context.model.setMode(.toggle)
        XCTAssertEqual(context.model.mode, .pushToTalk)

        context.model.cancelRecording()
        context.hotkeys.onKeyUp?()
        context.hotkeys.onKeyDown?()
        XCTAssertEqual(context.model.state, .idle)
        XCTAssertEqual(recorder.startCount, 1)

        recorder.stopURL = try appTemporaryFile()
        context.clock.advance(by: DictationTiming.shortcutDebounce + 0.01)
        context.hotkeys.onKeyDown?()
        await appWaitUntil("second recording") { context.model.state == .recording }
        XCTAssertEqual(recorder.startCount, 2)
        context.clock.advance(by: 1)
        context.hotkeys.onKeyUp?()
        await appWaitUntil("transcription") { context.model.state == .idle }
    }

    @MainActor
    func testPushToTalkKeyUpCancelsPendingPermission() async {
        let recorder = AppRecorderSpy()
        let permissions = PermissionSpy()
        permissions.holdMicrophoneRequest = true
        let context = makeContext(recorder: recorder, permissions: permissions)

        context.hotkeys.onKeyDown?()
        await Task.yield()
        XCTAssertEqual(context.model.state, .requestingPermission)
        context.hotkeys.onKeyUp?()
        permissions.resolveNextMicrophonePermission(true)
        await Task.yield()

        XCTAssertEqual(context.model.state, .idle)
        XCTAssertEqual(recorder.startCount, 0)
        XCTAssertEqual(recorder.cancelCount, 1)
    }

    @MainActor
    func testToggleStartsAndStopsRecording() async throws {
        let recorder = AppRecorderSpy()
        recorder.stopURL = try appTemporaryFile()
        var preferences = AppPreferences()
        preferences.triggerMode = .toggle
        let context = makeContext(recorder: recorder, preferences: preferences)

        context.hotkeys.onKeyDown?()
        await appWaitUntil("toggle recording") { context.model.state == .recording }
        context.hotkeys.onKeyUp?()
        context.clock.advance(by: 1)
        context.clock.advance(by: DictationTiming.shortcutDebounce + 0.01)
        context.hotkeys.onKeyDown?()
        await appWaitUntil("toggle transcription") { context.model.state == .idle }

        XCTAssertEqual(recorder.startCount, 1)
        XCTAssertEqual(recorder.stopCount, 1)
        XCTAssertEqual(context.listeningIndicator.labels, ["Listening…"])
        XCTAssertEqual(context.listeningIndicator.hideCount, 1)
    }

    @MainActor
    func testConnectionPermissionAndRecorderFailures() async {
        let deniedRecorder = AppRecorderSpy()
        let deniedPermissions = PermissionSpy()
        deniedPermissions.microphoneResult = false
        let denied = makeContext(recorder: deniedRecorder, permissions: deniedPermissions)
        denied.model.startSTTConnectionTest()
        await appWaitUntil("permission denied") { denied.model.connectionTestState.isInactive }
        XCTAssertEqual(
            denied.model.connectionTestState,
            .failed(.microphonePermissionDenied)
        )
        XCTAssertEqual(denied.feedback.events, [.error])

        let failingRecorder = AppRecorderSpy()
        failingRecorder.startError = AppStubError.failure
        let failing = makeContext(recorder: failingRecorder)
        failing.model.startSTTConnectionTest()
        await appWaitUntil("recorder failure") { failing.model.connectionTestState.isInactive }
        XCTAssertEqual(failing.model.connectionTestState, .failed(.recordingFailed(message: "Visible app failure")))
        XCTAssertTrue(failing.model.logStore.entries.contains { $0.message == "Error: connection test: Safe app failure" })
    }

    @MainActor
    func testShortConnectionRecordingFailsWithoutTranscription() async {
        let recorder = AppRecorderSpy()
        let transcriber = AppTranscriberSpy()
        let context = makeContext(recorder: recorder, transcriber: transcriber)

        context.model.startSTTConnectionTest()
        await appWaitUntil("test recording") { context.model.connectionTestState == .recording }
        context.model.finishSTTConnectionTest()

        XCTAssertEqual(
            context.model.connectionTestState,
            .failed(.insufficientAudio)
        )
        XCTAssertEqual(recorder.cancelCount, 1)
        let calls = await transcriber.calls
        XCTAssertTrue(calls.isEmpty)

        let missingRecorder = AppRecorderSpy()
        let missing = makeContext(recorder: missingRecorder)
        missing.model.startSTTConnectionTest()
        await appWaitUntil("missing file recording") { missing.model.connectionTestState == .recording }
        missing.clock.advance(by: 1)
        missing.model.finishSTTConnectionTest()
        XCTAssertEqual(
            missing.model.connectionTestState,
            .failed(.insufficientAudio)
        )
    }

    @MainActor
    func testSuccessfulConnectionTestForwardsConfigurationAndCleansCapture() async throws {
        let recorder = AppRecorderSpy()
        let audioURL = try appTemporaryFile()
        defer { try? FileManager.default.removeItem(at: audioURL) }
        recorder.stopURL = audioURL
        let transcriber = AppTranscriberSpy(result: .success("verified text"))
        var preferences = AppPreferences()
        preferences.sttPrompt = "vocabulary"
        preferences.sttLanguage = "fr"
        let context = makeContext(recorder: recorder, transcriber: transcriber, preferences: preferences)
        context.model.sttAPIKey = "connection-key"

        context.model.startSTTConnectionTest()
        await appWaitUntil("test recording") { context.model.connectionTestState == .recording }
        context.clock.advance(by: 1)
        context.model.finishSTTConnectionTest()
        await appWaitUntil("test success") { context.model.connectionTestState.isInactive }

        XCTAssertEqual(context.model.connectionTestState, .succeeded(characterCount: 13))
        let calls = await transcriber.calls
        XCTAssertEqual(calls.first?.configuration, preferences.stt)
        XCTAssertEqual(calls.first?.apiKey, "connection-key")
        XCTAssertEqual(calls.first?.prompt, "vocabulary")
        XCTAssertEqual(calls.first?.language, "fr")
        XCTAssertEqual(recorder.deleteCount, 1)
        XCTAssertEqual(context.feedback.events, [.recordingStarted, .recordingStopped, .connectionTestSucceeded])
    }

    @MainActor
    func testConnectionTranscriptionFailureAndCancellation() async throws {
        let failingRecorder = AppRecorderSpy()
        let failingURL = try appTemporaryFile()
        defer { try? FileManager.default.removeItem(at: failingURL) }
        failingRecorder.stopURL = failingURL
        let failingTranscriber = AppTranscriberSpy(result: .failure(.failure))
        let failing = makeContext(recorder: failingRecorder, transcriber: failingTranscriber)
        failing.model.startSTTConnectionTest()
        await appWaitUntil("failure recording") { failing.model.connectionTestState == .recording }
        failing.clock.advance(by: 1)
        failing.model.finishSTTConnectionTest()
        await appWaitUntil("connection failure") { failing.model.connectionTestState.isInactive }
        XCTAssertEqual(failing.model.connectionTestState, .failed(.transcriptionFailed(message: "Visible app failure")))
        XCTAssertTrue(failing.model.logStore.entries.contains { $0.message == "Error: connection test: Safe app failure" })

        let pendingRecorder = AppRecorderSpy()
        let pendingURL = try appTemporaryFile()
        defer { try? FileManager.default.removeItem(at: pendingURL) }
        pendingRecorder.stopURL = pendingURL
        let pendingTranscriber = AppControlledTranscriber()
        let pending = makeContext(recorder: pendingRecorder, transcriber: pendingTranscriber)
        pending.model.startSTTConnectionTest()
        await appWaitUntil("pending recording") { pending.model.connectionTestState == .recording }
        pending.clock.advance(by: 1)
        pending.model.finishSTTConnectionTest()
        await appWaitUntil("pending request") { await pendingTranscriber.callCount == 1 }
        pending.model.cancelSTTConnectionTest()
        await pendingTranscriber.succeed(with: "late transcript")
        await Task.yield()
        XCTAssertEqual(pending.model.connectionTestState, .idle)
        XCTAssertFalse(pending.model.logStore.entries.contains { $0.message.contains("late transcript") })
    }

    @MainActor
    func testConnectionTestBlocksDictationAndCanBeCancelled() async {
        let recorder = AppRecorderSpy()
        let permissions = PermissionSpy()
        permissions.holdMicrophoneRequest = true
        let context = makeContext(recorder: recorder, permissions: permissions)

        context.model.startSTTConnectionTest()
        await Task.yield()
        context.model.startRecording()
        XCTAssertEqual(context.model.state, .idle)
        context.model.cancelSTTConnectionTest()
        permissions.resolveNextMicrophonePermission(true)
        await Task.yield()

        XCTAssertEqual(context.model.connectionTestState, .idle)
        XCTAssertEqual(recorder.cancelCount, 1)
    }

    @MainActor
    func testPermissionsLaunchAtLoginFeedbackAndClipboardHelpers() async {
        let context = makeContext()
        context.permissions.microphonePermission = .denied
        context.permissions.accessibilityPermission = .granted

        XCTAssertEqual(context.model.microphonePermission, .denied)
        XCTAssertEqual(context.model.accessibilityPermission, .granted)
        let revision = context.model.permissionsRevision
        context.model.requestAccessibilityPermission()
        XCTAssertEqual(context.permissions.accessibilityRequestCount, 1)
        XCTAssertEqual(context.model.permissionsRevision, revision + 1)

        context.model.requestMicrophonePermission()
        await Task.yield()
        XCTAssertGreaterThan(context.model.permissionsRevision, revision + 1)

        context.model.setLaunchAtLogin(true)
        XCTAssertTrue(context.model.launchAtLoginEnabled)
        XCTAssertTrue(context.model.preferences.launchAtLogin)
        XCTAssertNil(context.model.launchAtLoginError)

        context.launch.error = AppStubError.failure
        context.model.setLaunchAtLogin(false)
        XCTAssertNotNil(context.model.launchAtLoginError)
        XCTAssertTrue(context.model.logStore.entries.contains { $0.message.contains("launch at login") })

        context.model.copyTestText()
        context.model.pasteTestText()
        context.model.copyTranscript()
        context.model.deliverTranscript()
        XCTAssertEqual(context.delivery.copied, ["Murmure — clipboard test"])
        XCTAssertEqual(context.delivery.pasted, ["Murmure — insertion test"])
    }

    @MainActor
    func testCompletedDictationCanBeCopiedAndDeliveredAgain() async throws {
        let recorder = AppRecorderSpy()
        recorder.stopURL = try appTemporaryFile()
        let context = makeContext(recorder: recorder)
        context.model.preferences.outputMode = .paste

        context.model.startRecording()
        await appWaitUntil("recording") { context.model.state == .recording }
        context.clock.advance(by: 1)
        context.model.stopRecording()
        await appWaitUntil("dictation completion") { context.model.state == .idle }
        context.model.copyTranscript()
        context.model.deliverTranscript()
        context.model.deleteLastCapture()

        XCTAssertEqual(context.delivery.copied, ["connection transcript"])
        XCTAssertEqual(context.delivery.pasted, ["connection transcript"])
        XCTAssertEqual(recorder.deleteCount, 1)
    }

    @MainActor
    func testDisabledFeedbackProducesNoSoundEvents() async {
        let recorder = AppRecorderSpy()
        let permissions = PermissionSpy()
        permissions.microphoneResult = false
        var preferences = AppPreferences()
        preferences.playFeedbackSounds = false
        let context = makeContext(recorder: recorder, preferences: preferences, permissions: permissions)

        context.model.startSTTConnectionTest()
        await appWaitUntil("silent failure") { context.model.connectionTestState.isInactive }
        XCTAssertTrue(context.feedback.events.isEmpty)
    }

    @MainActor
    func testPromptNavigationCreateSaveAndDiscardDraftLifecycle() {
        let context = makeContext()
        let state = PromptLibraryNavigationState()
        let id = UUID()

        state.beginCreating(id)
        XCTAssertTrue(state.isDirty)
        state.draft?.name = "Writing"
        state.draft?.instructions = "Improve prose."

        XCTAssertTrue(state.save(model: context.model))
        XCTAssertFalse(state.isDirty)
        XCTAssertEqual(context.model.preferences.cleanupPrompts.last?.id, id)

        state.draft?.instructions = "Changed locally."
        XCTAssertTrue(state.isDirty)
        state.discard()
        XCTAssertFalse(state.isDirty)
        XCTAssertEqual(state.draft?.instructions, "Improve prose.")
    }

    @MainActor
    func testPromptNavigationResetTransientStateClearsNavigationAndDraft() {
        let context = makeContext()
        let state = PromptLibraryNavigationState()
        let id = context.model.preferences.cleanupPrompts[0].id

        state.beginEditing(id, model: context.model)
        state.path = [.edit(id)]
        state.pendingAction = .back
        state.showUnsavedConfirmation = true

        state.resetTransientState()

        XCTAssertTrue(state.path.isEmpty)
        XCTAssertNil(state.draft)
        XCTAssertNil(state.originalDraft)
        XCTAssertNil(state.pendingAction)
        XCTAssertFalse(state.showUnsavedConfirmation)
    }

    func testListeningIndicatorFollowsDictationRecordingLifetime() async {
        let context = makeContext()

        context.model.startRecording()
        await appWaitUntil("recording") { context.model.state == .recording }

        XCTAssertEqual(context.listeningIndicator.labels, ["Listening…"])
        XCTAssertEqual(context.listeningIndicator.hideCount, 0)

        context.model.cancelRecording()

        XCTAssertEqual(context.model.state, .idle)
        XCTAssertEqual(context.listeningIndicator.hideCount, 1)
    }

    @MainActor
    func testListeningIndicatorRemainsVisibleDuringTranscription() async throws {
        let recorder = AppRecorderSpy()
        recorder.stopURL = try appTemporaryFile()
        let transcriber = AppControlledTranscriber()
        let cleaner = AppControlledCleaner()
        let context = makeContext(recorder: recorder, transcriber: transcriber, cleaner: cleaner)

        context.model.startRecording()
        await appWaitUntil("recording") { context.model.state == .recording }
        context.clock.advance(by: 1)
        context.model.stopRecording()
        await appWaitUntil("transcription request") { await transcriber.callCount == 1 }

        XCTAssertEqual(context.model.state, .transcribing)
        XCTAssertEqual(context.listeningIndicator.updatedLabels, ["Transcribing…"])
        XCTAssertEqual(context.listeningIndicator.hideCount, 0)

        await transcriber.succeed(with: "finished")
        await appWaitUntil("cleanup request") { await cleaner.callCount == 1 }
        XCTAssertEqual(context.listeningIndicator.updatedLabels, ["Transcribing…", "Improving text…"])
        XCTAssertEqual(context.listeningIndicator.hideCount, 0)

        await cleaner.succeed(with: "improved")
        await appWaitUntil("processing completion") { context.model.state == .idle }

        XCTAssertEqual(context.listeningIndicator.hideCount, 1)
    }

    @MainActor
    func testEscapeCancelsRecordingAndInFlightTranscription() async throws {
        let recorder = AppRecorderSpy()
        recorder.stopURL = try appTemporaryFile()
        let transcriber = AppControlledTranscriber()
        let context = makeContext(recorder: recorder, transcriber: transcriber)

        context.model.startRecording()
        await appWaitUntil("recording") { context.model.state == .recording }
        context.hotkeys.onEscape?()

        XCTAssertEqual(context.model.state, .idle)
        XCTAssertEqual(recorder.cancelCount, 1)

        recorder.stopURL = try appTemporaryFile()
        context.model.startRecording()
        await appWaitUntil("second recording") { context.model.state == .recording }
        context.clock.advance(by: 1)
        context.model.stopRecording()
        await appWaitUntil("transcription request") { await transcriber.callCount == 1 }

        context.hotkeys.onEscape?()
        XCTAssertEqual(context.model.state, .idle)
        XCTAssertEqual(context.listeningIndicator.hideCount, 2)

        await transcriber.succeed(with: "late result")
        await Task.yield()
        XCTAssertTrue(context.delivery.delivered.isEmpty)
    }
    }

    @MainActor
    private func makeContext(
        recorder: any AudioRecording = AppRecorderSpy(),
        transcriber: any SpeechTranscribing = AppTranscriberSpy(),
        cleaner: any TextCleaning = AppCleanerStub(),
        preferences: AppPreferences = AppPreferences(),
        secrets: [UUID: String] = [:],
        permissions: PermissionSpy = PermissionSpy()
    ) -> AppContext {
        let delivery = AppDeliverySpy()
        let logs = AppLogStore()
        let dependencies = DictationDependencies(
            audioRecorder: recorder,
            microphonePermission: permissions,
            textDelivery: delivery,
            transcriber: transcriber,
            cleaner: cleaner,
            logger: logs
        )
        let preferencesStore = PreferencesStoreSpy(preferences: preferences)
        let secretStore = SecretStoreSpy(secrets: secrets)
        let hotkeys = HotkeySpy()
        let launch = LaunchAtLoginSpy()
        let feedback = FeedbackSpy()
        let listeningIndicator = ListeningIndicatorSpy()
        let clock = AppDate()
        let coordinator = DictationCoordinator(
            dependencies: dependencies,
            now: { clock.value },
            sleep: { duration in try await Task.sleep(for: duration) }
        )
        let connectionTest = ConnectionTestModel(
            audioRecorder: recorder,
            microphonePermission: permissions,
            transcriber: transcriber,
            logger: logs,
            now: { clock.value }
        )
        let model = AppModel(dependencies: AppDependencies(
            coordinator: coordinator,
            connectionTest: connectionTest,
            textDelivery: delivery,
            preferencesStore: preferencesStore,
            keychain: secretStore,
            hotkeys: hotkeys,
            launchAtLogin: launch,
            feedback: feedback,
            listeningIndicator: listeningIndicator,
            permissions: permissions,
            logStore: logs,
            now: { clock.value }
        ))
        return AppContext(
            model: model,
            delivery: delivery,
            preferencesStore: preferencesStore,
            secretStore: secretStore,
            hotkeys: hotkeys,
            launch: launch,
            feedback: feedback,
            listeningIndicator: listeningIndicator,
            permissions: permissions,
            clock: clock
        )
    }
}

@MainActor
private struct AppContext {
    let model: AppModel
    let delivery: AppDeliverySpy
    let preferencesStore: PreferencesStoreSpy
    let secretStore: SecretStoreSpy
    let hotkeys: HotkeySpy
    let launch: LaunchAtLoginSpy
    let feedback: FeedbackSpy
    let listeningIndicator: ListeningIndicatorSpy
    let permissions: PermissionSpy
    let clock: AppDate
}
