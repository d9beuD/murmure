import AppKit
import MurmureCore
import SwiftUI

struct MenuContent: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                model.state.title,
                systemImage: model.state == .recording ? "record.circle.fill" : "waveform"
            )
            .font(.headline)

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

            SettingsLink {
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
