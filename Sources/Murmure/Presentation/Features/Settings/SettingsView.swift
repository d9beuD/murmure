import MurmureCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppStore
    let dockPresenceController: DockPresenceController
    @State private var selection: SettingsSection? = .general
    @State private var promptNavigation = PromptLibraryNavigationState()

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { selection },
                set: { newSelection in
                    guard newSelection != selection else { return }
                    if selection == .prompts, newSelection != .prompts, promptNavigation.isDirty {
                        promptNavigation.pendingAction = .leaveSettings(newSelection)
                        promptNavigation.showUnsavedConfirmation = true
                    } else {
                        selection = newSelection
                        if newSelection != .prompts {
                            promptNavigation.discard()
                            promptNavigation.path.removeAll()
                        }
                    }
                }
            )) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title(locale: model.interfaceLocale), systemImage: section.systemImageName)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:
                    GeneralSettingsView(model: model)
                case .stt:
                    STTSettingsView(model: model)
                case .dictationDictionary:
                    DictationDictionaryView(model: model)
                case .cleanup:
                    CleanupSettingsView(model: model)
                case .prompts:
                    PromptLibraryView(model: model, state: promptNavigation) { newSelection in
                        selection = newSelection
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, idealWidth: 920, minHeight: 520, idealHeight: 700)
        .background(DockPresenceWindowFocus(controller: dockPresenceController))
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case stt
    case dictationDictionary
    case cleanup
    case prompts

    var id: Self { self }

    var systemImageName: String {
        switch self {
        case .general: "gearshape"
        case .stt: "waveform"
        case .dictationDictionary: "character.book.closed"
        case .cleanup: "wand.and.stars"
        case .prompts: "text.badge.checkmark"
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .general: MurmureLocalization.text("settings.general", defaultValue: "General", locale: locale)
        case .stt: MurmureLocalization.text("settings.stt", defaultValue: "STT Transcription", locale: locale)
        case .dictationDictionary: MurmureLocalization.text("settings.dictation_dictionary", defaultValue: "Dictation Dictionary", locale: locale)
        case .cleanup: MurmureLocalization.text("settings.ttt", defaultValue: "TTT Cleanup", locale: locale)
        case .prompts: MurmureLocalization.text("settings.prompts", defaultValue: "Prompts", locale: locale)
        }
    }
}
