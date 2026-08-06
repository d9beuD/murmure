import AppKit
import MurmureCore
import SwiftUI

struct MenuContent: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Menu("Mode") {
            ForEach(TriggerMode.allCases) { mode in
                Button {
                    model.setMode(mode)
                } label: {
                    if model.mode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        }

        Divider()

        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        } label: {
            Label("Réglages", systemImage: "gear")
        }

        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "logs")
        } label: {
            Label("Logs", systemImage: "terminal")
        }

        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "onboarding")
        } label: {
            Label("Guide de démarrage", systemImage: "questionmark.circle")
        }

        Button("Quitter") {
            NSApplication.shared.terminate(nil)
        }
    }
}
