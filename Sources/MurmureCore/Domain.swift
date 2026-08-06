import Foundation
import Observation

public enum AuthenticationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case bearer
    case apiKey
    case none

    public var id: Self { self }
    public var title: String {
        switch self {
        case .bearer: "Bearer"
        case .apiKey: "Clé API"
        case .none: "Aucune"
        }
    }
}

public enum CleanupAPIFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case responses
    case chatCompletions

    public var id: Self { self }
    public var title: String {
        switch self {
        case .responses: "Responses API"
        case .chatCompletions: "Chat Completions"
        }
    }
}

public enum CleanupFailurePolicy: String, CaseIterable, Identifiable, Codable, Sendable {
    case useRawTranscript
    case stop

    public var id: Self { self }
    public var title: String {
        switch self {
        case .useRawTranscript: "Utiliser la transcription brute"
        case .stop: "Arrêter avec une erreur"
        }
    }
}

public struct ProviderConfiguration: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var baseURL: String
    public var path: String
    public var model: String
    public var authentication: AuthenticationMode
    public var customHeaderName: String
    public var timeout: Double

    public init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        path: String,
        model: String,
        authentication: AuthenticationMode = .bearer,
        customHeaderName: String = "Authorization",
        timeout: Double = 60
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.path = path
        self.model = model
        self.authentication = authentication
        self.customHeaderName = customHeaderName
        self.timeout = timeout
    }

    public var endpointURL: URL? {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: base), components.scheme == "https" || components.scheme == "http" else { return nil }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + suffix
        return components.url
    }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 3
    public var schemaVersion: Int
    public var stt: ProviderConfiguration
    public var sttLanguage: String
    public var sttPrompt: String
    public var triggerMode: TriggerMode
    public var cleanupEnabled: Bool
    public var cleanupProvider: ProviderConfiguration
    public var cleanupFormat: CleanupAPIFormat
    public var cleanupPrompt: String
    public var cleanupFailurePolicy: CleanupFailurePolicy
    public var outputMode: OutputMode

    public init(
        schemaVersion: Int = AppPreferences.currentSchemaVersion,
        stt: ProviderConfiguration = .openAITranscription,
        sttLanguage: String = "",
        sttPrompt: String = "",
        triggerMode: TriggerMode = .pushToTalk,
        cleanupEnabled: Bool = true,
        cleanupProvider: ProviderConfiguration = .openAIResponses,
        cleanupFormat: CleanupAPIFormat = .responses,
        cleanupPrompt: String = AppPreferences.defaultCleanupPrompt,
        cleanupFailurePolicy: CleanupFailurePolicy = .useRawTranscript,
        outputMode: OutputMode = .clipboard
    ) {
        self.schemaVersion = schemaVersion
        self.stt = stt
        self.sttLanguage = sttLanguage
        self.sttPrompt = sttPrompt
        self.triggerMode = triggerMode
        self.cleanupEnabled = cleanupEnabled
        self.cleanupProvider = cleanupProvider
        self.cleanupFormat = cleanupFormat
        self.cleanupPrompt = cleanupPrompt
        self.cleanupFailurePolicy = cleanupFailurePolicy
        self.outputMode = outputMode
    }

    public static let defaultCleanupPrompt = "Nettoie la transcription sans en changer le sens. Corrige la ponctuation, les fautes et les hésitations. Retourne uniquement le texte final."

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, stt, sttLanguage, sttPrompt, triggerMode, cleanupEnabled, cleanupProvider, cleanupFormat, cleanupPrompt, cleanupFailurePolicy, outputMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        stt = try container.decodeIfPresent(ProviderConfiguration.self, forKey: .stt) ?? .openAITranscription
        sttLanguage = try container.decodeIfPresent(String.self, forKey: .sttLanguage) ?? ""
        sttPrompt = try container.decodeIfPresent(String.self, forKey: .sttPrompt) ?? ""
        triggerMode = try container.decodeIfPresent(TriggerMode.self, forKey: .triggerMode) ?? .pushToTalk
        cleanupEnabled = try container.decodeIfPresent(Bool.self, forKey: .cleanupEnabled) ?? true
        cleanupProvider = try container.decodeIfPresent(ProviderConfiguration.self, forKey: .cleanupProvider) ?? .openAIResponses
        cleanupFormat = try container.decodeIfPresent(CleanupAPIFormat.self, forKey: .cleanupFormat) ?? .responses
        cleanupPrompt = try container.decodeIfPresent(String.self, forKey: .cleanupPrompt) ?? Self.defaultCleanupPrompt
        cleanupFailurePolicy = try container.decodeIfPresent(CleanupFailurePolicy.self, forKey: .cleanupFailurePolicy) ?? .useRawTranscript
        outputMode = try container.decodeIfPresent(OutputMode.self, forKey: .outputMode) ?? .clipboard
    }
}

public enum OutputMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case clipboard
    case paste
    public var id: Self { self }
    public var title: String { self == .clipboard ? "Presse-papiers" : "Insérer automatiquement" }
}

public extension ProviderConfiguration {
    static let openAITranscription = ProviderConfiguration(name: "OpenAI STT", baseURL: "https://api.openai.com/v1", path: "audio/transcriptions", model: "gpt-transcribe")
    static let openAIResponses = ProviderConfiguration(name: "OpenAI TTT", baseURL: "https://api.openai.com/v1", path: "responses", model: "gpt-5-mini")
}

public enum TriggerMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case pushToTalk
    case toggle

    public var id: Self { self }

    public var title: String {
        switch self {
        case .pushToTalk:
            "Maintenir pour parler"
        case .toggle:
            "Appuyer pour démarrer/arrêter"
        }
    }

}

public enum DictationTiming {
    public static let minimumRecordingDuration: TimeInterval = 0.25
    public static let maximumRecordingDuration: TimeInterval = 10 * 60
    public static let shortcutDebounce: TimeInterval = 0.15
}

public enum DictationState: Equatable, Sendable {
    case idle
    case requestingPermission
    case recording
    case transcribing
    case error(String)

    public var title: String {
        switch self {
        case .idle:
            "Prêt"
        case .requestingPermission:
            "Autorisation microphone…"
        case .recording:
            "Enregistrement…"
        case .transcribing:
            "Transcription…"
        case .error(let message):
            message
        }
    }
}

@MainActor
public protocol AudioRecording: AnyObject {
    func requestPermission() async -> Bool
    func start() throws
    func stop() -> URL?
    func cancel()
    func deleteLastCapture()
}

public extension AudioRecording {
    func requestPermission() async -> Bool { true }
}

public protocol SpeechTranscribing: Sendable {
    func transcribe(audioURL: URL, configuration: ProviderConfiguration, apiKey: String, prompt: String?, language: String?) async throws -> String
}

@MainActor
public protocol TextDelivering: AnyObject {
    func copy(_ text: String)
    func copyAndPaste(_ text: String)
}

@MainActor
public struct AppEnvironment {
    public let audioRecorder: any AudioRecording
    public let textDelivery: any TextDelivering
    public let transcriber: any SpeechTranscribing

    public init(
        audioRecorder: any AudioRecording,
        textDelivery: any TextDelivering,
        transcriber: any SpeechTranscribing
    ) {
        self.audioRecorder = audioRecorder
        self.textDelivery = textDelivery
        self.transcriber = transcriber
    }
}

@MainActor
@Observable
public final class DictationCoordinator {
    public private(set) var state: DictationState = .idle
    public private(set) var lastAudioURL: URL?
    public private(set) var lastTranscript: String?

    private let environment: AppEnvironment
    private var activeSessionID: UUID?
    private var permissionTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var recordingWatchdog: Task<Void, Never>?
    private var recordingStartedAt: Date?

    public var onRecordingTimeout: (() -> Void)?

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func startRecording() {
        guard state == .idle else { return }
        let sessionID = UUID()
        activeSessionID = sessionID
        state = .requestingPermission
        permissionTask = Task { [weak self] in
            guard let self else { return }
            guard await self.environment.audioRecorder.requestPermission() else {
                guard self.activeSessionID == sessionID else { return }
                self.activeSessionID = nil
                self.state = .error("Accès au microphone refusé. Autorisez Murmure dans Réglages Système.")
                return
            }
            guard self.activeSessionID == sessionID, self.state == .requestingPermission else { return }
            do {
                try self.environment.audioRecorder.start()
                self.recordingStartedAt = Date()
                self.state = .recording
                self.recordingWatchdog?.cancel()
                self.recordingWatchdog = Task { [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(DictationTiming.maximumRecordingDuration))
                    } catch {
                        return
                    }
                    guard let self, self.activeSessionID == sessionID, self.state == .recording else { return }
                    self.onRecordingTimeout?()
                }
            } catch {
                guard self.activeSessionID == sessionID else { return }
                self.activeSessionID = nil
                self.state = .error(error.localizedDescription)
            }
        }
    }

    public func stopRecording(configuration: ProviderConfiguration, apiKey: String, prompt: String?, language: String?) {
        guard state == .recording else { return }
        recordingWatchdog?.cancel()
        recordingWatchdog = nil
        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil
        if duration < DictationTiming.minimumRecordingDuration {
            environment.audioRecorder.cancel()
            activeSessionID = nil
            state = .idle
            return
        }
        lastAudioURL = environment.audioRecorder.stop()
        guard let audioURL = lastAudioURL else {
            state = .error("Aucun fichier audio n’a été produit.")
            return
        }
        guard let sessionID = activeSessionID else {
            state = .error("Session d’enregistrement introuvable.")
            return
        }
        state = .transcribing
        transcriptionTask?.cancel()
        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            defer {
                try? FileManager.default.removeItem(at: audioURL)
                if self.activeSessionID == sessionID {
                    self.activeSessionID = nil
                    self.lastAudioURL = nil
                }
            }
            do {
                let text = try await self.environment.transcriber.transcribe(
                    audioURL: audioURL,
                    configuration: configuration,
                    apiKey: apiKey,
                    prompt: prompt,
                    language: language
                )
                guard self.activeSessionID == sessionID else { return }
                self.lastTranscript = text
                self.activeSessionID = nil
                self.lastAudioURL = nil
                self.state = .idle
            } catch is CancellationError {
                guard self.activeSessionID == sessionID else { return }
                self.activeSessionID = nil
                self.lastAudioURL = nil
                self.state = .idle
            } catch {
                guard self.activeSessionID == sessionID else { return }
                self.activeSessionID = nil
                self.lastAudioURL = nil
                self.state = .error(error.localizedDescription)
            }
        }
    }

    public func cancelRecording() {
        activeSessionID = nil
        permissionTask?.cancel()
        permissionTask = nil
        recordingWatchdog?.cancel()
        recordingWatchdog = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        recordingStartedAt = nil
        environment.audioRecorder.cancel()
        lastAudioURL = nil
        state = .idle
    }

    public func deleteLastCapture() {
        environment.audioRecorder.deleteLastCapture()
        lastAudioURL = nil
    }
}
