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
    @State private var launchState: CompositionRoot.LaunchState
    @State private var dockPresenceController: DockPresenceController
    @State private var didOpenOnboarding = false
    @State private var didOpenRecoveryNotice = false
    @State private var didShowIncompatibleAlert = false
    @Environment(\.openWindow) private var openWindow

    init() {
        if LocalizationDiagnostic.runIfRequested() {
            exit(0)
        }
        if KeyboardShortcutsDiagnostic.runIfRequested() {
            exit(0)
        }
        _launchState = State(initialValue: CompositionRoot.makeLaunchState())
        _dockPresenceController = State(initialValue: DockPresenceController())
    }

    var body: some Scene {
        MenuBarExtra {
            if case .ready(let environment, let recoveredPreferences) = launchState {
                let model = environment.appStore
                MenuContent(model: model, updater: appDelegate.updaterController.updater)
                    .environment(\.locale, model.interfaceLocale)
                    .environment(model)
                    .environment(model.preferencesModel)
                    .environment(model.dictationSession)
                    .environment(model.permissionsModel)
                    .environment(model.promptLibrary)
                    .task {
                        guard model.requiresOnboarding, !recoveredPreferences, !didOpenOnboarding else { return }
                        didOpenOnboarding = true
                        openWindow(id: "onboarding")
                    }
                    .task {
                        guard recoveredPreferences, !didOpenRecoveryNotice else { return }
                        didOpenRecoveryNotice = true
                        openWindow(id: "startup-recovery")
                    }
            } else {
                Text(MurmureLocalization.text("startup.incompatible.title", defaultValue: "Murmure Update Required", locale: Locale(identifier: "en")))
                .task {
                    guard case .incompatible(let schemaVersion) = launchState, !didShowIncompatibleAlert else { return }
                    didShowIncompatibleAlert = true
                    presentIncompatibleAlert(schemaVersion: schemaVersion)
                }
                Button(MurmureLocalization.text("action.quit", defaultValue: "Quit", locale: Locale(identifier: "en"))) {
                    NSApplication.shared.terminate(nil)
                }
            }
        } label: {
            Image(nsImage: menuBarImage(for: readyModel?.state))
                .accessibilityLabel("Murmure")
        }
        .menuBarExtraStyle(.menu)

        Window(
            MurmureLocalization.text("window.settings", defaultValue: "Murmure Settings", locale: interfaceLocale),
            id: "settings"
        ) {
            if let model = readyModel {
                SettingsView(model: model, dockPresenceController: dockPresenceController)
                    .environment(\.locale, model.interfaceLocale)
                    .environment(model)
                    .environment(model.preferencesModel)
                    .environment(model.dictationSession)
                    .environment(model.permissionsModel)
                    .environment(model.promptLibrary)
            }
        }
        .defaultLaunchBehavior(.suppressed)

        Window(
            MurmureLocalization.text("window.logs", defaultValue: "Murmure Logs", locale: interfaceLocale),
            id: "logs"
        ) {
            if let model = readyModel {
                LogsView(logStore: model.logStore)
                    .environment(\.locale, model.interfaceLocale)
            }
        }
        .defaultLaunchBehavior(.suppressed)

        Window(
            MurmureLocalization.text("window.onboarding", defaultValue: "Welcome to Murmure", locale: interfaceLocale),
            id: "onboarding"
        ) {
            if let model = readyModel {
                OnboardingView(model: model, dockPresenceController: dockPresenceController)
                    .environment(\.locale, model.interfaceLocale)
                    .environment(model)
                    .environment(model.preferencesModel)
                    .environment(model.dictationSession)
                    .environment(model.permissionsModel)
                    .environment(model.promptLibrary)
            }
        }
        .defaultLaunchBehavior(.suppressed)

        Window(
            MurmureLocalization.text("startup.recovered.title", defaultValue: "Settings Recovered", locale: interfaceLocale),
            id: "startup-recovery"
        ) {
            StartupNoticeView(kind: .recovered, locale: interfaceLocale)
        }
        .defaultLaunchBehavior(.suppressed)
    }

    private var readyModel: AppStore? {
        guard case .ready(let environment, _) = launchState else { return nil }
        return environment.appStore
    }

    private var interfaceLocale: Locale {
        readyModel?.interfaceLocale ?? Locale(identifier: "en")
    }

    private func iconName(for state: DictationState?) -> String {
        guard let state else { return "exclamationmark.triangle.fill" }
        switch state {
        case .recording:
            return "record.circle.fill"
        case .transcribing:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        default:
            return "waveform"
        }
    }

    private func menuBarImage(for state: DictationState?) -> NSImage {
        let size: CGFloat = 18
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        guard let image = NSImage(
            systemSymbolName: iconName(for: state),
            accessibilityDescription: "Murmure"
        )?.withSymbolConfiguration(configuration) else {
            return NSImage(size: .init(width: size, height: size))
        }

        image.size = .init(width: size, height: size)
        image.isTemplate = true
        return image
    }

    private func presentIncompatibleAlert(schemaVersion: Int) {
        let locale = Locale(identifier: "en")
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = MurmureLocalization.text(
            "startup.incompatible.title",
            defaultValue: "Murmure Update Required",
            locale: locale
        )
        let format = MurmureLocalization.text(
            "startup.incompatible.message",
            defaultValue: "These settings were written by a newer version of Murmure (schema %lld). Update Murmure before using this installation so the newer settings are not overwritten.",
            locale: locale
        )
        alert.informativeText = String(format: format, locale: locale, arguments: [schemaVersion])
        alert.addButton(withTitle: MurmureLocalization.text(
            "menu.check_for_updates",
            defaultValue: "Check for Updates…",
            locale: locale
        ))
        alert.addButton(withTitle: MurmureLocalization.text("action.quit", defaultValue: "Quit", locale: locale))
        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            appDelegate.updaterController.updater.checkForUpdates()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
}

private enum StartupNoticeKind {
    case recovered
}

private struct StartupNoticeView: View {
    let kind: StartupNoticeKind
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: iconName)
                .font(.title2.bold())
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(MurmureLocalization.text("action.quit", defaultValue: "Quit", locale: locale)) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520, height: 220)
    }

    private var iconName: String {
        switch kind {
        case .recovered: "exclamationmark.triangle"
        }
    }

    private var title: String {
        switch kind {
        case .recovered:
            MurmureLocalization.text("startup.recovered.title", defaultValue: "Settings Recovered", locale: locale)
        }
    }

    private var message: String {
        switch kind {
        case .recovered:
            return MurmureLocalization.text(
                "startup.recovered.message",
                defaultValue: "Murmure could not read its settings. It created fresh settings and kept a private recovery copy. Please review your providers and API keys.",
                locale: locale
            )
        }
    }
}
