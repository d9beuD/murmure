import Foundation
import MurmureCore
import Observation

@MainActor
@Observable
final class PromptLibraryModel {
    private let preferencesModel: PreferencesModel

    init(preferencesModel: PreferencesModel) {
        self.preferencesModel = preferencesModel
    }

    var activePrompt: CleanupPrompt? {
        guard let activeID = preferences.activeCleanupPromptID else { return nil }
        return preferences.cleanupPrompts.first { $0.id == activeID }
    }

    var differsFromDefault: Bool {
        guard preferences.cleanupPrompts.count == 1,
              let prompt = preferences.cleanupPrompts.first else { return true }
        return prompt.name != "Standard"
            || prompt.systemImageName != "wand.and.stars"
            || prompt.instructions != MurmureLocalization.defaultCleanupPrompt(locale: interfaceLocale)
    }

    func setActive(_ id: UUID?) {
        guard id == nil || preferences.cleanupPrompts.contains(where: { $0.id == id }) else { return }
        guard preferences.activeCleanupPromptID != id else { return }
        preferences.activeCleanupPromptID = id
        if let activePrompt {
            preferences.cleanupPrompt = activePrompt.instructions
            preferences.cleanupPromptMode = .custom
        }
        preferencesModel.flushPendingWrites()
    }

    @discardableResult
    func save(_ prompt: CleanupPrompt) -> CleanupPromptValidationError? {
        let name = prompt.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .emptyName }
        guard !prompt.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .emptyInstructions
        }
        let normalizedName = name.filter { !$0.isWhitespace }
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if preferences.cleanupPrompts.contains(where: {
            $0.id != prompt.id
                && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).filter { !$0.isWhitespace }
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == normalizedName
        }) {
            return .duplicateName
        }
        guard CleanupPrompt.allowedSystemImageNames.contains(prompt.systemImageName) else {
            return .invalidIcon
        }

        var value = prompt
        value.name = name
        if let index = preferences.cleanupPrompts.firstIndex(where: { $0.id == prompt.id }) {
            preferences.cleanupPrompts[index] = value
        } else {
            preferences.cleanupPrompts.append(value)
        }
        if preferences.activeCleanupPromptID == nil {
            preferences.activeCleanupPromptID = value.id
        }
        if preferences.activeCleanupPromptID == value.id {
            preferences.cleanupPrompt = value.instructions
            preferences.cleanupPromptMode = .custom
        }
        preferencesModel.flushPendingWrites()
        return nil
    }

    func delete(id: UUID) {
        guard let index = preferences.cleanupPrompts.firstIndex(where: { $0.id == id }) else { return }
        preferences.cleanupPrompts.remove(at: index)
        if preferences.activeCleanupPromptID == id {
            preferences.activeCleanupPromptID = preferences.cleanupPrompts.first?.id
            if let activePrompt {
                preferences.cleanupPrompt = activePrompt.instructions
                preferences.cleanupPromptMode = .custom
            }
        }
        preferencesModel.flushPendingWrites()
    }

    func reset() {
        let prompt = CleanupPrompt(
            name: "Standard",
            systemImageName: "wand.and.stars",
            instructions: MurmureLocalization.defaultCleanupPrompt(locale: interfaceLocale)
        )
        preferences.cleanupPrompts = [prompt]
        preferences.activeCleanupPromptID = prompt.id
        preferences.cleanupPrompt = prompt.instructions
        preferences.cleanupPromptMode = .localizedDefault
        preferencesModel.flushPendingWrites()
    }

    private var preferences: AppPreferences {
        get { preferencesModel.preferences }
        set { preferencesModel.update(newValue, to: .immediate) }
    }

    private var interfaceLocale: Locale {
        MurmureLocalization.locale(for: preferences.interfaceLanguage)
    }
}
