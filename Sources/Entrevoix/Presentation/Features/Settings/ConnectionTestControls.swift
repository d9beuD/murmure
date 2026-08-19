import EntrevoixCore
import SwiftUI

struct ConnectionTestControls: View {
    let model: ConnectionTestStore

    var body: some View {
        let locale = model.interfaceLocale

        VStack(alignment: .leading, spacing: 8) {
            Text(EntrevoixLocalization.text("connection_test.description", defaultValue: "The test records a short phrase and sends it to the configured STT provider.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                switch model.state {
                case .recording:
                    Button(EntrevoixLocalization.text("action.stop_and_test", defaultValue: "Stop and Test", locale: locale)) {
                        model.finish()
                    }
                    .accessibilityHint(EntrevoixLocalization.text("accessibility.stop_and_test", defaultValue: "Stops the test recording and sends it to the STT provider.", locale: locale))

                    Button(EntrevoixLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) {
                        model.cancel()
                    }
                case .requestingPermission, .testing:
                    ProgressView()
                        .controlSize(.small)
                    Button(EntrevoixLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) {
                        model.cancel()
                    }
                case .idle, .succeeded, .failed:
                    Button(EntrevoixLocalization.text("action.start_test", defaultValue: "Start a Test", locale: locale)) {
                        model.start()
                    }
                    .accessibilityHint(EntrevoixLocalization.text("accessibility.start_test", defaultValue: "Requests microphone access, then starts a short test recording.", locale: locale))
                }
            }

            Label {
                Text(model.state.localizedTitle(locale: locale))
            } icon: {
                Image(systemName: iconName)
            }
            .font(.caption)
            .foregroundStyle(statusColor)
            .accessibilityLabel(EntrevoixLocalization.connectionStatus(model.state.localizedTitle(locale: locale), locale: locale))
        }
    }

    private var iconName: String {
        switch model.state {
        case .succeeded: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .recording: "record.circle.fill"
        case .requestingPermission, .testing: "arrow.triangle.2.circlepath"
        case .idle: "info.circle"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .succeeded: .green
        case .failed: .red
        case .idle: .secondary
        case .requestingPermission, .recording, .testing: .primary
        }
    }
}
