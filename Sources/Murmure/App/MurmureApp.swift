import AppKit
import SwiftUI
import MurmureCore
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
}

@main
struct MurmureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel
    @State private var didOpenOnboarding = false
    @Environment(\.openWindow) private var openWindow

    init() {
        _model = State(initialValue: CompositionRoot.makeAppModel())
    }

    var body: some Scene {
        MenuBarExtra("Murmure", systemImage: iconName(for: model.state)) {
            MenuContent(model: model, updater: appDelegate.updaterController.updater)
                .task {
                    guard model.requiresOnboarding, !didOpenOnboarding else { return }
                    didOpenOnboarding = true
                    openWindow(id: "onboarding")
                }
        }
        .menuBarExtraStyle(.menu)

        Window("Murmure Settings", id: "settings") {
            SettingsView(model: model)
        }
        .defaultLaunchBehavior(.suppressed)

        Window("Murmure Logs", id: "logs") {
            LogsView(logStore: model.logStore)
        }
        .defaultLaunchBehavior(.suppressed)

        Window("Welcome to Murmure", id: "onboarding") {
            OnboardingView(model: model)
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
