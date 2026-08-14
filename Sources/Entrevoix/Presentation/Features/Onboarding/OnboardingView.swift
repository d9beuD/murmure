import KeyboardShortcuts
import EntrevoixCore
import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppStore
    let dockPresenceController: DockPresenceController
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let stepCount = 5

    var body: some View {
        let locale = model.interfaceLocale

        VStack(alignment: .leading, spacing: 20) {
            ProgressView(value: Double(step + 1), total: Double(stepCount))
                .accessibilityLabel(EntrevoixLocalization.onboardingStep(step + 1, total: stepCount, locale: locale))

            Group {
                switch step {
                case 0: welcome
                case 1: sttConfiguration
                case 2: connectionTest
                case 3: shortcut
                default: delivery
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if step > 0 {
                    Button(EntrevoixLocalization.text("action.back", defaultValue: "Back", locale: locale)) { step -= 1 }
                }
                Spacer()
                if step < stepCount - 1 {
                    Button(EntrevoixLocalization.text("action.next", defaultValue: "Next", locale: locale)) {
                        model.savePreferences()
                        step += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(step == 1 && !isSTTConfigurationValid)
                } else {
                    Button(EntrevoixLocalization.text("action.finish", defaultValue: "Finish", locale: locale)) {
                        model.completeOnboarding()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 620, height: 500)
        .background(DockPresenceWindowFocus(controller: dockPresenceController))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(EntrevoixLocalization.text("onboarding.welcome.title", defaultValue: "Welcome to Entrevoix", locale: model.interfaceLocale), systemImage: "waveform")
                .font(.largeTitle.bold())
            Text(EntrevoixLocalization.text("onboarding.welcome.description", defaultValue: "Entrevoix records your voice locally, then sends the short audio file to your chosen STT provider. A second provider can then clean up the text if you enable that option.", locale: model.interfaceLocale))
            Text(EntrevoixLocalization.text("onboarding.welcome.privacy", defaultValue: "API keys stay in the macOS Keychain. Temporary audio files are deleted after dictation. Entrevoix has no servers or user accounts of its own.", locale: model.interfaceLocale))
                .foregroundStyle(.secondary)
            Label(EntrevoixLocalization.text("onboarding.welcome.settings_hint", defaultValue: "You can change all of these choices later in Settings.", locale: model.interfaceLocale), systemImage: "gear")
                .font(.callout)
            Picker(
                EntrevoixLocalization.text("settings.interface_language", defaultValue: "Interface language", locale: model.interfaceLocale),
                selection: Binding(
                    get: { model.preferences.interfaceLanguage },
                    set: { model.setInterfaceLanguage($0) }
                )
            ) {
                ForEach(InterfaceLanguage.allCases) { language in
                    Text(language.title(locale: model.interfaceLocale)).tag(language)
                }
            }
        }
    }

    private var sttConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(EntrevoixLocalization.text("onboarding.transcription.title", defaultValue: "Transcription connection", locale: model.interfaceLocale))
                .font(.title2.bold())
            Text(EntrevoixLocalization.text("onboarding.transcription.description", defaultValue: "Enter the OpenAI-compatible endpoint and STT model to use.", locale: model.interfaceLocale))
                .foregroundStyle(.secondary)
            TextField(EntrevoixLocalization.text("field.endpoint", defaultValue: "Endpoint", locale: model.interfaceLocale), text: $model.preferences.stt.baseURL)
            TextField(EntrevoixLocalization.text("field.path", defaultValue: "Path", locale: model.interfaceLocale), text: $model.preferences.stt.path)
            TextField(EntrevoixLocalization.text("field.model", defaultValue: "Model", locale: model.interfaceLocale), text: $model.preferences.stt.model)
            Picker(EntrevoixLocalization.text("field.stt_language", defaultValue: "Transcription language", locale: model.interfaceLocale), selection: Binding(
                get: { model.preferences.sttLanguage },
                set: { model.setSTTLanguage($0) }
            )) {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Text(language.title(locale: model.interfaceLocale)).tag(language)
                }
            }
            .pickerStyle(.menu)
            Picker(EntrevoixLocalization.text("field.authentication", defaultValue: "Authentication", locale: model.interfaceLocale), selection: $model.preferences.stt.authentication) {
                ForEach(AuthenticationMode.allCases) { Text($0.title(locale: model.interfaceLocale)).tag($0) }
            }
            if model.preferences.stt.authentication != .none {
                SecureField(EntrevoixLocalization.text("field.api_key", defaultValue: "API key", locale: model.interfaceLocale), text: $model.sttAPIKey)
            }
            if model.preferences.stt.authentication == .apiKey {
                TextField(EntrevoixLocalization.text("field.header_name", defaultValue: "Header name", locale: model.interfaceLocale), text: $model.preferences.stt.customHeaderName)
            }
            if let endpoint = model.preferences.stt.endpointURL {
                Label(endpoint.absoluteString, systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label(EntrevoixLocalization.text("validation.endpoint_scheme", defaultValue: "The endpoint must start with http:// or https://.", locale: model.interfaceLocale), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var connectionTest: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(EntrevoixLocalization.text("onboarding.connection.title", defaultValue: "Test the connection", locale: model.interfaceLocale))
                .font(.title2.bold())
            Text(EntrevoixLocalization.text("onboarding.connection.description", defaultValue: "This test is optional: speak a short phrase, then Entrevoix will send it to your STT provider. The test transcription is not retained.", locale: model.interfaceLocale))
                .foregroundStyle(.secondary)
            ConnectionTestControls(model: model)
            if model.microphonePermission != .granted {
                Button(EntrevoixLocalization.text("permission.allow_microphone", defaultValue: "Allow Microphone Access", locale: model.interfaceLocale)) {
                    model.requestMicrophonePermission()
                }
            }
        }
    }

    private var shortcut: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(EntrevoixLocalization.text("onboarding.shortcut.title", defaultValue: "Global shortcut", locale: model.interfaceLocale))
                .font(.title2.bold())
            Text(EntrevoixLocalization.text("onboarding.shortcut.description", defaultValue: "Choose the shortcut that will trigger Entrevoix, even when another app is in the foreground.", locale: model.interfaceLocale))
                .foregroundStyle(.secondary)
            KeyboardShortcuts.Recorder(EntrevoixLocalization.text("field.shortcut", defaultValue: "Shortcut:", locale: model.interfaceLocale), name: .dictation)
            Picker(EntrevoixLocalization.text("menu.mode", defaultValue: "Mode", locale: model.interfaceLocale), selection: Binding(
                get: { model.mode },
                set: { model.setMode($0) }
            )) {
                ForEach(TriggerMode.allCases) { mode in
                    Text(mode.title(locale: model.interfaceLocale)).tag(mode)
                }
            }
        }
    }

    private var delivery: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(EntrevoixLocalization.text("onboarding.delivery.title", defaultValue: "Delivery and preferences", locale: model.interfaceLocale))
                .font(.title2.bold())
            Picker(EntrevoixLocalization.text("field.dictation_output", defaultValue: "Dictation output", locale: model.interfaceLocale), selection: $model.preferences.outputMode) {
                ForEach(OutputMode.allCases) { Text($0.title(locale: model.interfaceLocale)).tag($0) }
            }
            if model.preferences.outputMode == .paste {
                Text(EntrevoixLocalization.text("permission.accessibility_insertion_hint", defaultValue: "Automatic insertion requires Accessibility permission. Without it, the text will be copied to the clipboard.", locale: model.interfaceLocale))
                    .foregroundStyle(.secondary)
                if model.accessibilityPermission != .granted {
                    Button(EntrevoixLocalization.text("permission.allow_accessibility", defaultValue: "Allow Automatic Insertion", locale: model.interfaceLocale)) {
                        model.requestAccessibilityPermission()
                    }
                }
            }
            Toggle(EntrevoixLocalization.text("settings.launch_at_login", defaultValue: "Launch Entrevoix at login", locale: model.interfaceLocale), isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            Toggle(EntrevoixLocalization.text("settings.play_feedback", defaultValue: "Play a sound when dictation starts and ends", locale: model.interfaceLocale), isOn: $model.preferences.playFeedbackSounds)
        }
    }

    private var isSTTConfigurationValid: Bool {
        guard model.preferences.stt.endpointURL != nil else { return false }
        guard !model.preferences.stt.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return model.preferences.stt.authentication == .none || !model.sttAPIKey.isEmpty
    }
}
