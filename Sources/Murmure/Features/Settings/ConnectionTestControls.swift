import MurmureCore
import SwiftUI

struct ConnectionTestControls: View {
    @Bindable var model: AppModel

    var body: some View {
        let locale = model.interfaceLocale

        VStack(alignment: .leading, spacing: 8) {
            Text(MurmureLocalization.text("connection_test.description", defaultValue: "The test records a short phrase and sends it to the configured STT provider.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                switch model.connectionTestState {
                case .recording:
                    Button(MurmureLocalization.text("action.stop_and_test", defaultValue: "Stop and Test", locale: locale)) {
                        model.finishSTTConnectionTest()
                    }
                    .accessibilityHint(MurmureLocalization.text("accessibility.stop_and_test", defaultValue: "Stops the test recording and sends it to the STT provider.", locale: locale))

                    Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) {
                        model.cancelSTTConnectionTest()
                    }
                case .requestingPermission, .testing:
                    ProgressView()
                        .controlSize(.small)
                    Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) {
                        model.cancelSTTConnectionTest()
                    }
                case .idle, .succeeded, .failed:
                    Button(MurmureLocalization.text("action.start_test", defaultValue: "Start a Test", locale: locale)) {
                        model.startSTTConnectionTest()
                    }
                    .accessibilityHint(MurmureLocalization.text("accessibility.start_test", defaultValue: "Requests microphone access, then starts a short test recording.", locale: locale))
                }
            }

            Label {
                Text(model.connectionTestState.localizedTitle(locale: locale))
            } icon: {
                Image(systemName: iconName)
            }
            .font(.caption)
            .foregroundStyle(statusColor)
            .accessibilityLabel(MurmureLocalization.connectionStatus(model.connectionTestState.localizedTitle(locale: locale), locale: locale))
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
