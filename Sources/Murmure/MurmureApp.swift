import SwiftUI

@main
struct MurmureApp: App {
    @State private var model: AppModel

    init() {
        _model = State(initialValue: AppModel(environment: LiveEnvironment.make()))
    }

    var body: some Scene {
        MenuBarExtra("Murmure", systemImage: "waveform") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.menu)

        Window("Réglages de Murmure", id: "settings") {
            SettingsView(model: model)
        }
        .defaultLaunchBehavior(.suppressed)
    }
}
