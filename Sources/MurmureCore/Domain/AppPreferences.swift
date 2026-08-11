public struct AppPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 5
    public var schemaVersion: Int
    public var interfaceLanguage: InterfaceLanguage
    public var stt: ProviderConfiguration
    public var sttLanguage: String
    public var sttPrompt: String
    public var triggerMode: TriggerMode
    public var cleanupEnabled: Bool
    public var cleanupProvider: ProviderConfiguration
    public var cleanupFormat: CleanupAPIFormat
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
        sttLanguage: String = "", sttPrompt: String = "", triggerMode: TriggerMode = .pushToTalk,
        cleanupEnabled: Bool = true, cleanupProvider: ProviderConfiguration = .openAIResponses,
        cleanupFormat: CleanupAPIFormat = .responses, cleanupPrompt: String = AppPreferences.defaultCleanupPrompt,
        cleanupPromptMode: CleanupPromptMode = .localizedDefault,
        cleanupFailurePolicy: CleanupFailurePolicy = .useRawTranscript, outputMode: OutputMode = .clipboard,
        launchAtLogin: Bool = false, playFeedbackSounds: Bool = true, hasCompletedOnboarding: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.interfaceLanguage = interfaceLanguage
        self.stt = stt
        self.sttLanguage = sttLanguage
        self.sttPrompt = sttPrompt
        self.triggerMode = triggerMode
        self.cleanupEnabled = cleanupEnabled
        self.cleanupProvider = cleanupProvider
        self.cleanupFormat = cleanupFormat
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
        case schemaVersion, interfaceLanguage, stt, sttLanguage, sttPrompt, triggerMode, cleanupEnabled, cleanupProvider, cleanupFormat, cleanupPrompt, cleanupPromptMode, cleanupFailurePolicy, outputMode, launchAtLogin, playFeedbackSounds, hasCompletedOnboarding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        schemaVersion = decodedSchemaVersion
        interfaceLanguage = try container.decodeIfPresent(InterfaceLanguage.self, forKey: .interfaceLanguage) ?? .automatic
        stt = try container.decodeIfPresent(ProviderConfiguration.self, forKey: .stt) ?? .openAITranscription
        sttLanguage = try container.decodeIfPresent(String.self, forKey: .sttLanguage) ?? ""
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
        cleanupFailurePolicy = try container.decodeIfPresent(CleanupFailurePolicy.self, forKey: .cleanupFailurePolicy) ?? .useRawTranscript
        outputMode = try container.decodeIfPresent(OutputMode.self, forKey: .outputMode) ?? .clipboard
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        playFeedbackSounds = try container.decodeIfPresent(Bool.self, forKey: .playFeedbackSounds) ?? true
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? (decodedSchemaVersion < 4)
    }
}
