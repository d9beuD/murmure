import MurmureCore
import SwiftUI

struct ConnectionTestControls: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The test records a short phrase and sends it to the configured STT provider.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                switch model.connectionTestState {
                case .recording:
                    Button("Stop and Test") {
                        model.finishSTTConnectionTest()
                    }
                    .accessibilityHint("Stops the test recording and sends it to the STT provider.")

                    Button("Cancel", role: .cancel) {
                        model.cancelSTTConnectionTest()
                    }
                case .requestingPermission, .testing:
                    ProgressView()
                        .controlSize(.small)
                    Button("Cancel", role: .cancel) {
                        model.cancelSTTConnectionTest()
                    }
                case .idle, .succeeded, .failed:
                    Button("Start a Test") {
                        model.startSTTConnectionTest()
                    }
                    .accessibilityHint("Requests microphone access, then starts a short test recording.")
                }
            }

            Label {
                Text(model.connectionTestState.title)
            } icon: {
                Image(systemName: iconName)
            }
            .font(.caption)
            .foregroundStyle(statusColor)
            .accessibilityLabel("Connection test status: \(model.connectionTestState.title)")
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
