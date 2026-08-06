import SwiftUI
import MurmureCore

@main
struct MurmureApp: App {
    @State private var model: AppModel

    init() {
        _model = State(initialValue: AppModel(environment: LiveEnvironment.make()))
    }

    var body: some Scene {
        MenuBarExtra("Murmure", systemImage: iconName(for: model.state)) {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.menu)

        Window("Réglages de Murmure", id: "settings") {
            SettingsView(model: model)
        }
        .defaultLaunchBehavior(.suppressed)

        Window("Logs de Murmure", id: "logs") {
            LogsView(logStore: model.logStore)
        }
        .defaultLaunchBehavior(.suppressed)
    }

    private func iconName(for state: DictationState) -> String {
        switch state {
        case .recording:
            "record.circle.fill"
        case .transcribing:
            "arrow.triangle.2.circlepath"
        case .error:
            "exclamationmark.triangle.fill"
        default:
            "waveform"
        }
    }
}
