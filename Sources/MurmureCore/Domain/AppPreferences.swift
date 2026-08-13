import Foundation

public struct AppPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 7
    public static let defaultCleanupPromptID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    public var schemaVersion: Int
    public var interfaceLanguage: InterfaceLanguage
    public var stt: ProviderConfiguration
    public var sttLanguage: TranscriptionLanguage
    public var sttFavoriteLanguages: [TranscriptionLanguage]
    public var sttPrompt: String
    public var triggerMode: TriggerMode
    public var cleanupEnabled: Bool
    public var cleanupProvider: ProviderConfiguration
    public var cleanupFormat: CleanupAPIFormat
    public var cleanupPrompts: [CleanupPrompt]
    public var activeCleanupPromptID: UUID?
    // Kept for decoding preferences written before the prompt library existed.
    public var cleanupPrompt: String
    public var cleanupPromptMode: CleanupPromptMode
    public var cleanupFailurePolicy: CleanupFailurePolicy
    public var outputMode: OutputMode
    public var launchAtLogin: Bool
    public var playFeedbackSounds: Bool
    public var hasCompletedOnboarding: Bool

    public init(
        schemaVersion: Int = AppPreferences.currentSchemaVersion,
        interfaceLanguage: InterfaceLanguage = .automatic,
        stt: ProviderConfiguration = .openAITranscription,
        sttLanguage: TranscriptionLanguage = .automatic,
        sttFavoriteLanguages: [TranscriptionLanguage] = [.french, .english],
        sttPrompt: String = "", triggerMode: TriggerMode = .pushToTalk,
        cleanupEnabled: Bool = true, cleanupProvider: ProviderConfiguration = .openAIResponses,
        cleanupFormat: CleanupAPIFormat = .responses, cleanupPrompt: String = AppPreferences.defaultCleanupPrompt,
        cleanupPromptMode: CleanupPromptMode = .localizedDefault,
        cleanupPrompts: [CleanupPrompt] = [CleanupPrompt(
            id: AppPreferences.defaultCleanupPromptID,
            name: "Standard",
            systemImageName: "wand.and.stars",
            instructions: AppPreferences.defaultCleanupPrompt
        )],
        activeCleanupPromptID: UUID? = nil,
        cleanupFailurePolicy: CleanupFailurePolicy = .useRawTranscript, outputMode: OutputMode = .clipboard,
        launchAtLogin: Bool = false, playFeedbackSounds: Bool = true, hasCompletedOnboarding: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.interfaceLanguage = interfaceLanguage
        self.stt = stt
        self.sttLanguage = sttLanguage
        var normalizedFavorites = Self.normalizedFavoriteLanguages(sttFavoriteLanguages)
        if sttLanguage != .automatic && !normalizedFavorites.contains(sttLanguage) {
            normalizedFavorites.append(sttLanguage)
        }
        self.sttFavoriteLanguages = normalizedFavorites
        self.sttPrompt = sttPrompt
        self.triggerMode = triggerMode
        self.cleanupEnabled = cleanupEnabled
        self.cleanupProvider = cleanupProvider
        self.cleanupFormat = cleanupFormat
        self.cleanupPrompts = cleanupPrompts
        self.activeCleanupPromptID = activeCleanupPromptID ?? cleanupPrompts.first?.id
        self.cleanupPrompt = cleanupPrompt
        self.cleanupPromptMode = cleanupPromptMode
        self.cleanupFailurePolicy = cleanupFailurePolicy
        self.outputMode = outputMode
        self.launchAtLogin = launchAtLogin
        self.playFeedbackSounds = playFeedbackSounds
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    public static let defaultCleanupPrompt = "Clean up the transcript without changing its meaning. Correct punctuation, mistakes, and hesitations. Return only the final text."

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, interfaceLanguage, stt, sttLanguage, sttFavoriteLanguages, sttPrompt, triggerMode, cleanupEnabled, cleanupProvider, cleanupFormat, cleanupPrompts, activeCleanupPromptID, cleanupPrompt, cleanupPromptMode, cleanupFailurePolicy, outputMode, launchAtLogin, playFeedbackSounds, hasCompletedOnboarding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        schemaVersion = decodedSchemaVersion
        interfaceLanguage = try container.decodeIfPresent(InterfaceLanguage.self, forKey: .interfaceLanguage) ?? .automatic
        stt = try container.decodeIfPresent(ProviderConfiguration.self, forKey: .stt) ?? .openAITranscription
        if let rawLanguage = try? container.decode(String.self, forKey: .sttLanguage) {
            sttLanguage = TranscriptionLanguage(legacyCode: rawLanguage)
        } else {
            sttLanguage = .automatic
        }
        if let rawFavorites = try? container.decode([String].self, forKey: .sttFavoriteLanguages) {
            sttFavoriteLanguages = Self.normalizedFavoriteLanguages(rawFavorites.map(TranscriptionLanguage.init(legacyCode:)))
        } else {
            sttFavoriteLanguages = [.french, .english]
        }
        if sttLanguage != .automatic && !sttFavoriteLanguages.contains(sttLanguage) {
            sttFavoriteLanguages.append(sttLanguage)
        }
        sttPrompt = try container.decodeIfPresent(String.self, forKey: .sttPrompt) ?? ""
        triggerMode = try container.decodeIfPresent(TriggerMode.self, forKey: .triggerMode) ?? .pushToTalk
        cleanupEnabled = try container.decodeIfPresent(Bool.self, forKey: .cleanupEnabled) ?? true
        cleanupProvider = try container.decodeIfPresent(ProviderConfiguration.self, forKey: .cleanupProvider) ?? .openAIResponses
        cleanupFormat = try container.decodeIfPresent(CleanupAPIFormat.self, forKey: .cleanupFormat) ?? .responses
        cleanupPrompt = try container.decodeIfPresent(String.self, forKey: .cleanupPrompt) ?? Self.defaultCleanupPrompt
        if let decodedMode = try container.decodeIfPresent(CleanupPromptMode.self, forKey: .cleanupPromptMode) {
            cleanupPromptMode = decodedMode
        } else if cleanupPrompt == Self.defaultCleanupPrompt {
            cleanupPromptMode = .legacyDefaultPendingChoice
        } else {
            cleanupPromptMode = .custom
        }
        if let decodedPrompts = try container.decodeIfPresent([CleanupPrompt].self, forKey: .cleanupPrompts) {
            cleanupPrompts = decodedPrompts
            activeCleanupPromptID = try container.decodeIfPresent(UUID.self, forKey: .activeCleanupPromptID)
        } else {
            let legacyPrompt = CleanupPrompt(
                name: cleanupPromptMode == .custom ? "Existing Prompt" : "Standard",
                systemImageName: cleanupPromptMode == .custom ? "text.badge.checkmark" : "wand.and.stars",
                instructions: cleanupPrompt
            )
            cleanupPrompts = [legacyPrompt]
            activeCleanupPromptID = legacyPrompt.id
        }
        cleanupFailurePolicy = try container.decodeIfPresent(CleanupFailurePolicy.self, forKey: .cleanupFailurePolicy) ?? .useRawTranscript
        outputMode = try container.decodeIfPresent(OutputMode.self, forKey: .outputMode) ?? .clipboard
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        playFeedbackSounds = try container.decodeIfPresent(Bool.self, forKey: .playFeedbackSounds) ?? true
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? (decodedSchemaVersion < 4)
    }

    private static func normalizedFavoriteLanguages(_ languages: [TranscriptionLanguage]) -> [TranscriptionLanguage] {
        var result: [TranscriptionLanguage] = []
        for language in languages where language != .automatic && !result.contains(language) {
            result.append(language)
        }
        return result
    }
}
