import MurmureCore
import SwiftUI

struct ConnectionTestControls: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Le test enregistre une courte phrase et l’envoie au fournisseur STT configuré.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                switch model.connectionTestState {
                case .recording:
                    Button("Arrêter et tester") {
                        model.finishSTTConnectionTest()
                    }
                    .accessibilityHint("Arrête l’enregistrement de test et l’envoie au fournisseur STT.")

                    Button("Annuler", role: .cancel) {
                        model.cancelSTTConnectionTest()
                    }
                case .requestingPermission, .testing:
                    ProgressView()
                        .controlSize(.small)
                    Button("Annuler", role: .cancel) {
                        model.cancelSTTConnectionTest()
                    }
                case .idle, .succeeded, .failed:
                    Button("Démarrer un test") {
                        model.startSTTConnectionTest()
                    }
                    .accessibilityHint("Demande le microphone puis commence un court enregistrement de test.")
                }
            }

            Label {
                Text(model.connectionTestState.title)
            } icon: {
                Image(systemName: iconName)
            }
            .font(.caption)
            .foregroundStyle(statusColor)
            .accessibilityLabel("État du test de connexion : \(model.connectionTestState.title)")
        }
    }

    private var iconName: String {
        switch model.connectionTestState {
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .recording: "record.circle.fill"
        case .requestingPermission, .testing: "arrow.triangle.2.circlepath"
        case .idle: "info.circle"
        }
    }

    private var statusColor: Color {
        switch model.connectionTestState {
        case .succeeded: .green
        case .failed: .red
        case .idle: .secondary
        case .requestingPermission, .recording, .testing: .primary
        }
    }
}
