import Foundation
import MurmureCore

@MainActor
struct AppDependencies {
    let coordinator: DictationCoordinator
    let connectionTest: ConnectionTestModel
    let textDelivery: any TextDelivering
    let preferencesStore: any PreferencesStoring
    let keychain: any SecretStoring
    let hotkeys: any HotkeyHandling
    let launchAtLogin: any LaunchAtLoginControlling
    let feedback: any FeedbackPlaying
    let permissions: any PermissionProviding
    let logStore: AppLogStore
    let now: () -> Date
}
