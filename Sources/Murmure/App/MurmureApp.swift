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
                .environment(\.locale, model.interfaceLocale)
                .task {
                    guard model.requiresOnboarding, !didOpenOnboarding else { return }
                    didOpenOnboarding = true
                    openWindow(id: "onboarding")
                }
        }
        .menuBarExtraStyle(.menu)

        Window(
            MurmureLocalization.text("window.settings", defaultValue: "Murmure Settings", locale: model.interfaceLocale),
            id: "settings"
        ) {
            SettingsView(model: model)
                .environment(\.locale, model.interfaceLocale)
        }
        .defaultLaunchBehavior(.suppressed)

        Window(
            MurmureLocalization.text("window.logs", defaultValue: "Murmure Logs", locale: model.interfaceLocale),
            id: "logs"
        ) {
            LogsView(logStore: model.logStore)
                .environment(\.locale, model.interfaceLocale)
        }
        .defaultLaunchBehavior(.suppressed)

        Window(
            MurmureLocalization.text("window.onboarding", defaultValue: "Welcome to Murmure", locale: model.interfaceLocale),
            id: "onboarding"
        ) {
            OnboardingView(model: model)
                .environment(\.locale, model.interfaceLocale)
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
