import AppKit
import KeyboardShortcuts
import MurmureCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        let locale = model.interfaceLocale

        Form {
            Section(MurmureLocalization.text("settings.general", defaultValue: "General", locale: locale)) {
                Picker(MurmureLocalization.text("settings.interface_language", defaultValue: "Interface language", locale: locale), selection: $model.preferences.interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(language.title(locale: locale)).tag(language)
                    }
                }
                Toggle(MurmureLocalization.text("settings.launch_at_login", defaultValue: "Launch Murmure at login", locale: locale), isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle(MurmureLocalization.text("settings.play_feedback", defaultValue: "Play a sound when dictation starts and ends", locale: locale), isOn: $model.preferences.playFeedbackSounds)
                if let launchAtLoginError = model.launchAtLoginError {
                    Label(launchAtLoginError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Section(MurmureLocalization.text("settings.global_shortcut", defaultValue: "Global Shortcut", locale: locale)) {
                KeyboardShortcuts.Recorder(MurmureLocalization.text("field.shortcut", defaultValue: "Shortcut:", locale: locale), name: .dictation)

                Picker(MurmureLocalization.text("menu.mode", defaultValue: "Mode", locale: locale), selection: Binding(
                    get: { model.mode },
                    set: { model.setMode($0) }
                )) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title(locale: locale)).tag(mode)
                    }
                }
            }

            Section(MurmureLocalization.text("settings.stt", defaultValue: "STT Transcription", locale: locale)) {
                TextField(MurmureLocalization.text("field.name", defaultValue: "Name", locale: locale), text: $model.preferences.stt.name)
                TextField(MurmureLocalization.text("field.endpoint", defaultValue: "Endpoint", locale: locale), text: $model.preferences.stt.baseURL)
                TextField(MurmureLocalization.text("field.path", defaultValue: "Path", locale: locale), text: $model.preferences.stt.path)
                TextField(MurmureLocalization.text("field.model", defaultValue: "Model", locale: locale), text: $model.preferences.stt.model)
                TextField(MurmureLocalization.text("field.stt_language_optional", defaultValue: "Language (optional)", locale: locale), text: $model.preferences.sttLanguage)
                TextField(MurmureLocalization.text("field.context_prompt_optional", defaultValue: "Context prompt (optional)", locale: locale), text: $model.preferences.sttPrompt)
                Picker(MurmureLocalization.text("field.authentication", defaultValue: "Authentication", locale: locale), selection: $model.preferences.stt.authentication) {
                    ForEach(AuthenticationMode.allCases) { Text($0.title(locale: locale)).tag($0) }
                }
                if model.preferences.stt.authentication != .none {
                    SecureField(MurmureLocalization.text("field.api_key", defaultValue: "API key", locale: locale), text: $model.sttAPIKey)
                    if model.preferences.stt.authentication == .apiKey {
                        TextField(MurmureLocalization.text("field.header_name", defaultValue: "Header name", locale: locale), text: $model.preferences.stt.customHeaderName)
                    }
                }
                validation(for: model.preferences.stt, locale: locale)
                ConnectionTestControls(model: model)
            }

            Section(MurmureLocalization.text("settings.ttt", defaultValue: "TTT Cleanup", locale: locale)) {
                Toggle(MurmureLocalization.text("settings.enable_cleanup", defaultValue: "Enable cleanup", locale: locale), isOn: $model.preferences.cleanupEnabled)
                if model.preferences.cleanupEnabled {
                    TextField(MurmureLocalization.text("field.endpoint", defaultValue: "Endpoint", locale: locale), text: $model.preferences.cleanupProvider.baseURL)
                    TextField(MurmureLocalization.text("field.path", defaultValue: "Path", locale: locale), text: $model.preferences.cleanupProvider.path)
                    TextField(MurmureLocalization.text("field.model", defaultValue: "Model", locale: locale), text: $model.preferences.cleanupProvider.model)
                    Picker(MurmureLocalization.text("field.authentication", defaultValue: "Authentication", locale: locale), selection: $model.preferences.cleanupProvider.authentication) {
                        ForEach(AuthenticationMode.allCases) { Text($0.title(locale: locale)).tag($0) }
                    }
                    Picker(MurmureLocalization.text("field.format", defaultValue: "Format", locale: locale), selection: $model.preferences.cleanupFormat) {
                        ForEach(CleanupAPIFormat.allCases) { Text($0.title(locale: locale)).tag($0) }
                    }
                    if model.preferences.cleanupProvider.authentication != .none {
                        SecureField(MurmureLocalization.text("field.api_key", defaultValue: "API key", locale: locale), text: $model.cleanupAPIKey)
                    }
                    if model.preferences.cleanupProvider.authentication == .apiKey {
                        TextField(MurmureLocalization.text("field.header_name", defaultValue: "Header name", locale: locale), text: $model.preferences.cleanupProvider.customHeaderName)
                    }
                    TextEditor(text: Binding(
                        get: { model.cleanupPromptForDisplay },
                        set: {
                            model.preferences.cleanupPrompt = $0
                            model.preferences.cleanupPromptMode = .custom
                        }
                    ))
                    .frame(minHeight: 80)
                    Button(MurmureLocalization.text("cleanup.reset_prompt", defaultValue: "Reset Prompt", locale: locale)) { model.resetCleanupPrompt() }
                    Picker(MurmureLocalization.text("cleanup.on_failure", defaultValue: "On failure", locale: locale), selection: $model.preferences.cleanupFailurePolicy) {
                        ForEach(CleanupFailurePolicy.allCases) { Text($0.title(locale: locale)).tag($0) }
                    }
                    validation(for: model.preferences.cleanupProvider, locale: locale)
                }
            }

            Section(MurmureLocalization.text("settings.delivery", defaultValue: "Delivery", locale: locale)) {
                Picker(MurmureLocalization.text("field.output", defaultValue: "Output", locale: locale), selection: $model.preferences.outputMode) {
                    ForEach(OutputMode.allCases) { Text($0.title(locale: locale)).tag($0) }
                }
            }

            Section(MurmureLocalization.text("settings.permissions", defaultValue: "Permissions", locale: locale)) {
                permissionRow(MurmureLocalization.text("permission.microphone", defaultValue: "Microphone", locale: locale), status: model.microphonePermission, locale: locale)
                if model.microphonePermission != .granted {
                    Button(MurmureLocalization.text("permission.allow_microphone", defaultValue: "Allow Microphone Access", locale: locale)) { model.requestMicrophonePermission() }
                }
                permissionRow(MurmureLocalization.text("permission.accessibility", defaultValue: "Accessibility", locale: locale), status: model.accessibilityPermission, locale: locale)
                if model.accessibilityPermission != .granted {
                    Button(MurmureLocalization.text("permission.allow_accessibility", defaultValue: "Allow Automatic Insertion", locale: locale)) { model.requestAccessibilityPermission() }
                }
                Button(MurmureLocalization.text("permission.refresh", defaultValue: "Refresh Permissions", locale: locale)) { model.refreshPermissions() }
                Text(MurmureLocalization.text("permission.accessibility_insertion_hint", defaultValue: "Accessibility permission is only required for automatic insertion. Without it, Murmure uses the clipboard.", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(MurmureLocalization.text("settings.about", defaultValue: "About", locale: locale)) {
                Text(MurmureLocalization.text("settings.version", defaultValue: "Murmure 0.1.0 — MIT License", locale: locale))
                Link(MurmureLocalization.text("settings.source_code", defaultValue: "Source code on GitHub", locale: locale), destination: URL(string: "https://github.com/d9beuD/murmure")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 760)
        .padding()
        .onChange(of: model.preferences) { _, _ in model.savePreferences() }
        .onChange(of: model.sttAPIKey) { _, _ in model.savePreferences() }
        .onChange(of: model.cleanupAPIKey) { _, _ in model.savePreferences() }
        .alert(
            MurmureLocalization.text("cleanup.migration.title", defaultValue: "Use the French cleanup prompt?", locale: locale),
            isPresented: Binding(
                get: { model.shouldOfferCleanupPromptMigration },
                set: { _ in }
            )
        ) {
            Button(MurmureLocalization.text("cleanup.migration.accept", defaultValue: "Use French Prompt", locale: locale)) {
                model.acceptLocalizedCleanupPrompt()
            }
            Button(MurmureLocalization.text("cleanup.migration.keep", defaultValue: "Keep English Prompt", locale: locale), role: .cancel) {
                model.keepLegacyCleanupPrompt()
            }
        } message: {
            Text(MurmureLocalization.text("cleanup.migration.message", defaultValue: "Your existing default prompt is in English. You can use a French version that will follow the interface language.", locale: locale))
        }
        .background(SettingsWindowFocus())
    }

    @ViewBuilder
    private func validation(for provider: ProviderConfiguration, locale: Locale) -> some View {
        if provider.endpointURL == nil {
            Label(MurmureLocalization.text("validation.invalid_url", defaultValue: "Invalid URL: use http:// or https://", locale: locale), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        } else if provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Label(MurmureLocalization.text("validation.model_required", defaultValue: "A model is required.", locale: locale), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    private func permissionRow(_ name: String, status: PermissionStatus, locale: Locale) -> some View {
        HStack {
            Text(name)
            Spacer()
            Label(status.title(locale: locale), systemImage: status == .granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(status == .granted ? .green : .orange)
        }
        .accessibilityLabel(MurmureLocalization.permissionStatus(name: name, status: status.title(locale: locale), locale: locale))
    }
}

/// A menubar-only app is not automatically activated when its Settings scene opens.
private struct SettingsWindowFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeMain()
            window.makeKey()
        }
    }
}
