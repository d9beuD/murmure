import AppKit
import KeyboardShortcuts
import MurmureCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch Murmure at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle("Play a sound when dictation starts and ends", isOn: $model.preferences.playFeedbackSounds)
                if let launchAtLoginError = model.launchAtLoginError {
                    Label(launchAtLoginError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Section("Global Shortcut") {
                KeyboardShortcuts.Recorder("Shortcut:", name: .dictation)

                Picker("Mode", selection: Binding(
                    get: { model.mode },
                    set: { model.setMode($0) }
                )) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("STT Transcription") {
                TextField("Name", text: $model.preferences.stt.name)
                TextField("Endpoint", text: $model.preferences.stt.baseURL)
                TextField("Path", text: $model.preferences.stt.path)
                TextField("Model", text: $model.preferences.stt.model)
                TextField("Language (optional)", text: $model.preferences.sttLanguage)
                TextField("Context prompt (optional)", text: $model.preferences.sttPrompt)
                Picker("Authentication", selection: $model.preferences.stt.authentication) {
                    ForEach(AuthenticationMode.allCases) { Text($0.title).tag($0) }
                }
                if model.preferences.stt.authentication != .none {
                    SecureField("API key", text: $model.sttAPIKey)
                    if model.preferences.stt.authentication == .apiKey {
                        TextField("Header name", text: $model.preferences.stt.customHeaderName)
                    }
                }
                validation(for: model.preferences.stt)
                ConnectionTestControls(model: model)
            }

            Section("TTT Cleanup") {
                Toggle("Enable cleanup", isOn: $model.preferences.cleanupEnabled)
                if model.preferences.cleanupEnabled {
                    TextField("Endpoint", text: $model.preferences.cleanupProvider.baseURL)
                    TextField("Path", text: $model.preferences.cleanupProvider.path)
                    TextField("Model", text: $model.preferences.cleanupProvider.model)
                    Picker("Authentication", selection: $model.preferences.cleanupProvider.authentication) {
                        ForEach(AuthenticationMode.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Format", selection: $model.preferences.cleanupFormat) {
                        ForEach(CleanupAPIFormat.allCases) { Text($0.title).tag($0) }
                    }
                    if model.preferences.cleanupProvider.authentication != .none {
                        SecureField("API key", text: $model.cleanupAPIKey)
                    }
                    if model.preferences.cleanupProvider.authentication == .apiKey {
                        TextField("Header name", text: $model.preferences.cleanupProvider.customHeaderName)
                    }
                    TextEditor(text: $model.preferences.cleanupPrompt)
                        .frame(minHeight: 80)
                    Button("Reset Prompt") { model.resetCleanupPrompt() }
                    Picker("On failure", selection: $model.preferences.cleanupFailurePolicy) {
                        ForEach(CleanupFailurePolicy.allCases) { Text($0.title).tag($0) }
                    }
                    validation(for: model.preferences.cleanupProvider)
                }
            }

            Section("Delivery") {
                Picker("Output", selection: $model.preferences.outputMode) {
                    ForEach(OutputMode.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Permissions") {
                permissionRow("Microphone", status: model.microphonePermission)
                if model.microphonePermission != .granted {
                    Button("Allow Microphone Access") { model.requestMicrophonePermission() }
                }
                permissionRow("Accessibility", status: model.accessibilityPermission)
                if model.accessibilityPermission != .granted {
                    Button("Allow Automatic Insertion") { model.requestAccessibilityPermission() }
                }
                Button("Refresh Permissions") { model.refreshPermissions() }
                Text("Accessibility permission is only required for automatic insertion. Without it, Murmure uses the clipboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("Murmure 0.1.0 — MIT License")
                Link("Source code on GitHub", destination: URL(string: "https://github.com/d9beuD/murmure")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 760)
        .padding()
        .onChange(of: model.preferences) { _, _ in model.savePreferences() }
        .onChange(of: model.sttAPIKey) { _, _ in model.savePreferences() }
        .onChange(of: model.cleanupAPIKey) { _, _ in model.savePreferences() }
        .background(SettingsWindowFocus())
    }

    @ViewBuilder
    private func validation(for provider: ProviderConfiguration) -> some View {
        if provider.endpointURL == nil {
            Label("Invalid URL: use http:// or https://", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        } else if provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Label("A model is required.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        }
    }

    private func permissionRow(_ name: String, status: PermissionStatus) -> some View {
        HStack {
            Text(name)
            Spacer()
            Label(status.title, systemImage: status == .granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(status == .granted ? .green : .orange)
        }
        .accessibilityLabel("\(name): \(status.title)")
    }
}

/// A menubar-only app is not automatically activated when its Settings scene opens.
/// Make the SwiftUI Settings window key so its title bar is active and it appears above
/// the window that launched it.
private struct SettingsWindowFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

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
