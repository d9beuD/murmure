import Foundation

/// Applies schema migrations that require coordinated changes across preference fields.
///
/// `AppPreferences` remains responsible for tolerant decoding. This type owns the
/// version-aware normalization that is safe to run after decoding and before the
/// preferences are handed to the application models.
public enum PreferencesMigrator {
    public static func migrate(
        _ input: AppPreferences,
        localizedDefaultPrompt: String
    ) -> AppPreferences {
        var preferences = input
        let sourceSchemaVersion = input.schemaVersion

        if sourceSchemaVersion < AppPreferences.currentSchemaVersion {
            preferences.schemaVersion = AppPreferences.currentSchemaVersion
        }

        if sourceSchemaVersion < 6 {
            let wasLocalized = input.cleanupPromptMode != .custom
            var migrated = input.cleanupPrompts.first
                ?? CleanupPrompt(
                    name: wasLocalized ? defaultPromptName : "Existing Prompt",
                    systemImageName: wasLocalized ? defaultPromptIcon : "text.badge.checkmark",
                    instructions: input.cleanupPrompt
                )

            if wasLocalized {
                migrated.name = defaultPromptName
                migrated.systemImageName = defaultPromptIcon
                migrated.instructions = localizedDefaultPrompt
            } else {
                migrated.name = "Existing Prompt"
            }

            preferences.cleanupPrompts = [migrated]
            preferences.activeCleanupPromptID = migrated.id
        } else if let activeID = input.activeCleanupPromptID {
            if !input.cleanupPrompts.contains(where: { $0.id == activeID }) {
                preferences.activeCleanupPromptID = input.cleanupPrompts.first?.id
            }
        } else if !input.cleanupPrompts.isEmpty {
            preferences.activeCleanupPromptID = input.cleanupPrompts.first?.id
        }

        if sourceSchemaVersion == AppPreferences.currentSchemaVersion,
           !input.hasCompletedOnboarding,
           input.cleanupPromptMode == .localizedDefault,
           preferences.cleanupPrompts.count == 1,
           preferences.cleanupPrompts[0].instructions == AppPreferences.defaultCleanupPrompt {
            preferences.cleanupPrompts[0].instructions = localizedDefaultPrompt
        }

        return preferences
    }

    private static let defaultPromptName = "Standard"
    private static let defaultPromptIcon = "wand.and.stars"
}
