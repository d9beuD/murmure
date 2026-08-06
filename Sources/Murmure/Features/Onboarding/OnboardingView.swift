import AppKit
import KeyboardShortcuts
import MurmureCore
import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let stepCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView(value: Double(step + 1), total: Double(stepCount))
                .accessibilityLabel("Étape \(step + 1) sur \(stepCount)")

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
                    Button("Précédent") { step -= 1 }
                }
                Spacer()
                if step < stepCount - 1 {
                    Button("Suivant") {
                        model.savePreferences()
                        step += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(step == 1 && !isSTTConfigurationValid)
                } else {
                    Button("Terminer") {
                        model.completeOnboarding()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 620, height: 500)
        .background(OnboardingWindowFocus())
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Bienvenue dans Murmure", systemImage: "waveform")
                .font(.largeTitle.bold())
            Text("Murmure enregistre votre voix localement, puis envoie le court fichier audio au fournisseur STT que vous choisissez. Le texte peut ensuite être nettoyé par un second fournisseur, si vous l’activez.")
            Text("Les clés API restent dans le Trousseau macOS. Les fichiers audio temporaires sont supprimés après la dictée. Murmure ne possède aucun serveur ni compte utilisateur.")
                .foregroundStyle(.secondary)
            Label("Vous pourrez modifier tous ces choix dans Réglages.", systemImage: "gear")
                .font(.callout)
        }
    }

    private var sttConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connexion de transcription")
                .font(.title2.bold())
            Text("Indiquez l’endpoint compatible OpenAI et le modèle STT à utiliser.")
                .foregroundStyle(.secondary)
            TextField("Endpoint", text: $model.preferences.stt.baseURL)
            TextField("Chemin", text: $model.preferences.stt.path)
            TextField("Modèle", text: $model.preferences.stt.model)
            Picker("Authentification", selection: $model.preferences.stt.authentication) {
                ForEach(AuthenticationMode.allCases) { Text($0.title).tag($0) }
            }
            if model.preferences.stt.authentication != .none {
                SecureField("Clé API", text: $model.sttAPIKey)
            }
            if model.preferences.stt.authentication == .apiKey {
                TextField("Nom de l’en-tête", text: $model.preferences.stt.customHeaderName)
            }
            if let endpoint = model.preferences.stt.endpointURL {
                Label(endpoint.absoluteString, systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label("L’endpoint doit commencer par http:// ou https://.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var connectionTest: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tester la connexion")
                .font(.title2.bold())
            Text("Ce test est volontaire : dites une courte phrase, puis Murmure l’enverra à votre fournisseur STT. Aucune transcription de test n’est conservée.")
                .foregroundStyle(.secondary)
            ConnectionTestControls(model: model)
            if model.microphonePermission != .granted {
                Button("Autoriser le microphone") {
                    model.requestMicrophonePermission()
                }
            }
        }
    }

    private var shortcut: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Raccourci global")
                .font(.title2.bold())
            Text("Choisissez le raccourci qui déclenchera Murmure, même lorsqu’une autre application est au premier plan.")
                .foregroundStyle(.secondary)
            KeyboardShortcuts.Recorder("Raccourci :", name: .dictation)
            Picker("Mode", selection: Binding(
                get: { model.mode },
                set: { model.setMode($0) }
            )) {
                ForEach(TriggerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        }
    }

    private var delivery: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Livraison et préférences")
                .font(.title2.bold())
            Picker("Résultat de la dictée", selection: $model.preferences.outputMode) {
                ForEach(OutputMode.allCases) { Text($0.title).tag($0) }
            }
            if model.preferences.outputMode == .paste {
                Text("L’insertion automatique nécessite l’autorisation Accessibilité. Sans elle, le texte sera copié dans le presse-papiers.")
                    .foregroundStyle(.secondary)
                if model.accessibilityPermission != .granted {
                    Button("Autoriser l’insertion automatique") {
                        model.requestAccessibilityPermission()
                    }
                }
            }
            Toggle("Lancer Murmure à l’ouverture de session", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            Toggle("Jouer un son au début et à la fin d’une dictée", isOn: $model.preferences.playFeedbackSounds)
        }
    }

    private var isSTTConfigurationValid: Bool {
        guard model.preferences.stt.endpointURL != nil else { return false }
        guard !model.preferences.stt.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return model.preferences.stt.authentication == .none || !model.sttAPIKey.isEmpty
    }
}

private struct OnboardingWindowFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
