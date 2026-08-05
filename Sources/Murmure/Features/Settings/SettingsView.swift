import KeyboardShortcuts
import MurmureCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Raccourci global") {
                KeyboardShortcuts.Recorder("Raccourci :", name: .dictation)

                Picker("Mode", selection: $model.mode) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Fondation J1") {
                Text("Le domaine et la coordination sont séparés de l’interface et des services macOS.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 260)
        .padding()
    }
}
