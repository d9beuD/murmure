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
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var stt: ProviderConfiguration
    public var cleanupEnabled: Bool
    public var cleanupProvider: ProviderConfiguration
    public var cleanupFormat: CleanupAPIFormat
    public var cleanupPrompt: String
    public var cleanupFailurePolicy: CleanupFailurePolicy
    public var outputMode: OutputMode

    public init(
        schemaVersion: Int = AppPreferences.currentSchemaVersion,
        stt: ProviderConfiguration = .openAITranscription,
        cleanupEnabled: Bool = true,
        cleanupProvider: ProviderConfiguration = .openAIResponses,
        cleanupFormat: CleanupAPIFormat = .responses,
        cleanupPrompt: String = AppPreferences.defaultCleanupPrompt,
        cleanupFailurePolicy: CleanupFailurePolicy = .useRawTranscript,
        outputMode: OutputMode = .clipboard
    ) {
        self.schemaVersion = schemaVersion
        self.stt = stt
        self.cleanupEnabled = cleanupEnabled
        self.cleanupProvider = cleanupProvider
        self.cleanupFormat = cleanupFormat
        self.cleanupPrompt = cleanupPrompt
        self.cleanupFailurePolicy = cleanupFailurePolicy
        self.outputMode = outputMode
    }

    public static let defaultCleanupPrompt = "Nettoie la transcription sans en changer le sens. Corrige la ponctuation, les fautes et les hésitations. Retourne uniquement le texte final."
}

public enum OutputMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case clipboard
    case paste
    public var id: Self { self }
    public var title: String { self == .clipboard ? "Presse-papiers" : "Insérer automatiquement" }
}

public extension ProviderConfiguration {
    static let openAITranscription = ProviderConfiguration(name: "OpenAI STT", baseURL: "https://api.openai.com/v1", path: "audio/transcriptions", model: "gpt-4o-mini-transcribe")
    static let openAIResponses = ProviderConfiguration(name: "OpenAI TTT", baseURL: "https://api.openai.com/v1", path: "responses", model: "gpt-5-mini")
}

public enum TriggerMode: String, CaseIterable, Identifiable, Sendable {
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

public enum DictationState: Equatable, Sendable {
    case idle
    case recording
    case error(String)

    public var title: String {
        switch self {
        case .idle:
            "Prêt"
        case .recording:
            "Enregistrement…"
        case .error(let message):
            message
        }
    }
}

@MainActor
public protocol AudioRecording: AnyObject {
    func start() throws
    func stop() -> URL?
    func cancel()
    func deleteLastCapture()
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

    public init(
        audioRecorder: any AudioRecording,
        textDelivery: any TextDelivering
    ) {
        self.audioRecorder = audioRecorder
        self.textDelivery = textDelivery
    }
}

@MainActor
@Observable
public final class DictationCoordinator {
    public private(set) var state: DictationState = .idle
    public private(set) var lastAudioURL: URL?

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func startRecording() {
        guard state != .recording else { return }

        do {
            try environment.audioRecorder.start()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func stopRecording() {
        guard state == .recording else { return }
        lastAudioURL = environment.audioRecorder.stop()
        state = .idle
    }

    public func cancelRecording() {
        environment.audioRecorder.cancel()
        state = .idle
    }

    public func deleteLastCapture() {
        environment.audioRecorder.deleteLastCapture()
        lastAudioURL = nil
    }
}
