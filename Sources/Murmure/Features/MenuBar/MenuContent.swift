import AppKit
import MurmureCore
import SwiftUI

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                model.state.title,
                systemImage: model.state == .recording ? "record.circle.fill" : model.state == .transcribing ? "arrow.triangle.2.circlepath" : "waveform"
            )
            .font(.headline)

            if Bundle.main.bundleURL.pathExtension != "app" {
                Label(
                    "Lancement incomplet : utilisez Scripts/run-app.sh",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Picker("Mode", selection: $model.mode) {
                ForEach(TriggerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Divider()

            if model.state == .recording {
                Button("Arrêter") {
                    model.stopRecording()
                }

                Button("Annuler", role: .cancel) {
                    model.cancelRecording()
                }
            } else if model.state == .idle {
                Button("Démarrer") {
                    model.startRecording()
                }
            } else if case .error = model.state {
                Button("Réessayer") {
                    model.cancelRecording()
                    model.startRecording()
                }
            }

            if let transcript = model.lastTranscript {
                Divider()
                Text("Dernière transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(transcript)
                    .textSelection(.enabled)
                    .lineLimit(5)
                Button("Copier la transcription") { model.copyTranscript() }
                Button(model.preferences.outputMode == .paste ? "Insérer la transcription" : "Copier et livrer") {
                    model.deliverTranscript()
                }
            }

            Divider()

            Button("Copier un texte de test") {
                model.copyTestText()
            }

            Button("Insérer un texte de test") {
                model.pasteTestText()
            }

            if let lastAudioURL = model.lastAudioURL {
                Text(lastAudioURL.path)
                    .font(.caption)
                    .textSelection(.enabled)

                Button("Supprimer la capture") {
                    model.deleteLastCapture()
                }
            }

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            } label: {
                Label("Réglages", systemImage: "gear")
            }

            Button("Quitter Murmure") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}
