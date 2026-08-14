import Foundation

public enum CleanupPromptValidationError: Error, Equatable, Sendable {
    case emptyName
    case duplicateName
    case emptyInstructions
    case invalidIcon
}

public enum CleanupPromptLibrary {
    public static func validatedSaving(
        _ prompt: CleanupPrompt,
        into prompts: [CleanupPrompt]
    ) -> Result<CleanupPrompt, CleanupPromptValidationError> {
        let name = prompt.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .failure(.emptyName) }
        guard !prompt.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyInstructions)
        }
        guard CleanupPrompt.allowedSystemImageNames.contains(prompt.systemImageName) else {
            return .failure(.invalidIcon)
        }
        let normalizedName = normalized(name)
        guard !prompts.contains(where: { $0.id != prompt.id && normalized($0.name) == normalizedName }) else {
            return .failure(.duplicateName)
        }
        var value = prompt
        value.name = name
        return .success(value)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace }
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
