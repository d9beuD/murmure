import AppKit
import MurmureCore
import Sparkle
import SwiftUI

struct MenuContent: View {
    @Bindable var model: AppModel
    let updater: SPUUpdater
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let locale = model.interfaceLocale

        Menu(MurmureLocalization.text("menu.language", defaultValue: "Language", locale: locale)) {
            Button {
                model.setSTTLanguage(.automatic)
            } label: {
                languageMenuLabel(.automatic, locale: locale, isSelected: model.preferences.sttLanguage == .automatic)
            }

            if !model.preferences.sttFavoriteLanguages.isEmpty {
                Divider()
                ForEach(TranscriptionLanguage.sortedForDisplay(locale: locale).filter { model.preferences.sttFavoriteLanguages.contains($0) }) { language in
                    Button {
                        model.setSTTLanguage(language)
                    } label: {
                        languageMenuLabel(language, locale: locale, isSelected: model.preferences.sttLanguage == language)
                    }
                }
            }
        }

        Menu(MurmureLocalization.text("menu.mode", defaultValue: "Mode", locale: locale)) {
            ForEach(TriggerMode.allCases) { mode in
                Button {
                    model.setMode(mode)
                } label: {
                    if model.mode == mode {
                        Label(mode.title(locale: locale), systemImage: "checkmark")
                    } else {
                        Text(mode.title(locale: locale))
                    }
                }
            }
        }

        Menu(MurmureLocalization.text("menu.prompt", defaultValue: "Prompt", locale: locale)) {
            if model.preferences.cleanupPrompts.isEmpty {
                Text(MurmureLocalization.text("prompts.none", defaultValue: "No prompts saved", locale: locale))
            } else {
                ForEach(model.preferences.cleanupPrompts) { prompt in
                    Button {
                        model.setActiveCleanupPrompt(prompt.id)
                    } label: {
                        HStack {
                            Label(prompt.name, systemImage: prompt.systemImageName)
                            if model.preferences.activeCleanupPromptID == prompt.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            Divider()
            Text(
                model.preferences.cleanupEnabled
                    ? MurmureLocalization.text("menu.prompt_enabled", defaultValue: "TTT cleanup enabled", locale: locale)
                    : MurmureLocalization.text("menu.prompt_disabled", defaultValue: "TTT cleanup disabled", locale: locale)
            )
            .foregroundStyle(.secondary)
        }

        Divider()

        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        } label: {
            Label(MurmureLocalization.text("menu.settings", defaultValue: "Settings", locale: locale), systemImage: "gear")
        }

        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "logs")
        } label: {
            Label(MurmureLocalization.text("menu.logs", defaultValue: "Logs", locale: locale), systemImage: "terminal")
        }

        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "onboarding")
        } label: {
            Label(MurmureLocalization.text("menu.getting_started", defaultValue: "Getting Started", locale: locale), systemImage: "questionmark.circle")
        }

        Divider()

        Button(MurmureLocalization.text("menu.check_for_updates", defaultValue: "Check for Updates…", locale: locale)) {
            updater.checkForUpdates()
        }

        Button(MurmureLocalization.text("menu.quit", defaultValue: "Quit", locale: locale)) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func languageMenuLabel(_ language: TranscriptionLanguage, locale: Locale, isSelected: Bool) -> some View {
        HStack {
            Text(language.title(locale: locale))
            if isSelected {
                Spacer()
                Image(systemName: "checkmark")
            }
        }
    }
}
