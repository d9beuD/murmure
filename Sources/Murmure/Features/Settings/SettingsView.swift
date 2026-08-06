import AppKit
import KeyboardShortcuts
import MurmureCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Raccourci global") {
                KeyboardShortcuts.Recorder("Raccourci :", name: .dictation)

                Picker("Mode", selection: $model.mode) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Transcription STT") {
                TextField("Nom", text: $model.preferences.stt.name)
                TextField("Endpoint", text: $model.preferences.stt.baseURL)
                TextField("Chemin", text: $model.preferences.stt.path)
                TextField("Modèle", text: $model.preferences.stt.model)
                Picker("Authentification", selection: $model.preferences.stt.authentication) {
                    ForEach(AuthenticationMode.allCases) { Text($0.title).tag($0) }
                }
                if model.preferences.stt.authentication != .none {
                    SecureField("Clé API", text: $model.sttAPIKey)
                    if model.preferences.stt.authentication == .apiKey {
                        TextField("Nom de l’en-tête", text: $model.preferences.stt.customHeaderName)
                    }
                }
                validation(for: model.preferences.stt)
            }

            Section("Nettoyage TTT") {
                Toggle("Activer le nettoyage", isOn: $model.preferences.cleanupEnabled)
                if model.preferences.cleanupEnabled {
                    TextField("Endpoint", text: $model.preferences.cleanupProvider.baseURL)
                    TextField("Chemin", text: $model.preferences.cleanupProvider.path)
                    TextField("Modèle", text: $model.preferences.cleanupProvider.model)
                    Picker("Authentification", selection: $model.preferences.cleanupProvider.authentication) {
                        ForEach(AuthenticationMode.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Format", selection: $model.preferences.cleanupFormat) {
                        ForEach(CleanupAPIFormat.allCases) { Text($0.title).tag($0) }
                    }
                    if model.preferences.cleanupProvider.authentication != .none {
                        SecureField("Clé API", text: $model.cleanupAPIKey)
                    }
                    if model.preferences.cleanupProvider.authentication == .apiKey {
                        TextField("Nom de l’en-tête", text: $model.preferences.cleanupProvider.customHeaderName)
                    }
                    TextEditor(text: $model.preferences.cleanupPrompt)
                        .frame(minHeight: 80)
                    Button("Réinitialiser le prompt") { model.resetCleanupPrompt() }
                    Picker("En cas d'échec", selection: $model.preferences.cleanupFailurePolicy) {
                        ForEach(CleanupFailurePolicy.allCases) { Text($0.title).tag($0) }
                    }
                    validation(for: model.preferences.cleanupProvider)
                }
            }

            Section("Livraison") {
                Picker("Sortie", selection: $model.preferences.outputMode) {
                    ForEach(OutputMode.allCases) { Text($0.title).tag($0) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 680)
        .padding()
        .onChange(of: model.preferences) { _, _ in model.savePreferences() }
        .onChange(of: model.sttAPIKey) { _, _ in model.savePreferences() }
        .onChange(of: model.cleanupAPIKey) { _, _ in model.savePreferences() }
        .background(SettingsWindowFocus())
    }

    @ViewBuilder
    private func validation(for provider: ProviderConfiguration) -> some View {
        if provider.endpointURL == nil {
            Label("URL invalide : utilisez http:// ou https://", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        } else if provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Label("Le modèle est obligatoire.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.caption)
        }
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
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}
