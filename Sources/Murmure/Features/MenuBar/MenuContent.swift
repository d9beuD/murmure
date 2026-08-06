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
                systemImage: model.state == .recording ? "record.circle.fill" : "waveform"
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
            } else {
                Button("Démarrer") {
                    model.startRecording()
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
                Label("Réglages du raccourci", systemImage: "gear")
            }

            Button("Quitter Murmure") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}
