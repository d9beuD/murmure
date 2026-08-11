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
        case .apiKey: "API Key"
        case .none: "None"
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
        case .useRawTranscript: "Use Raw Transcript"
        case .stop: "Stop with an Error"
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
        var basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedSuffix = suffix.lowercased()

        // OpenAI-compatible providers commonly expose their API below /v1,
        // while users usually enter only the host (for example 127.0.0.1:8001).
        // Keep custom paths untouched and add /v1 only for known OpenAI routes.
        let knownOpenAIRoute = ["audio/transcriptions", "responses", "chat/completions"].contains(normalizedSuffix)
        if knownOpenAIRoute, basePath.split(separator: "/").contains("v1") == false,
           basePath.hasSuffix(suffix) == false {
            basePath = basePath.isEmpty ? "v1" : "\(basePath)/v1"
        }

        if basePath.hasSuffix(suffix) == false {
            basePath = basePath.isEmpty ? suffix : "\(basePath)/\(suffix)"
        }
        components.path = "/" + basePath
        return components.url
    }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 4
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
    public var launchAtLogin: Bool
    public var playFeedbackSounds: Bool
    public var hasCompletedOnboarding: Bool

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
        outputMode: OutputMode = .clipboard,
        launchAtLogin: Bool = false,
        playFeedbackSounds: Bool = true,
        hasCompletedOnboarding: Bool = false
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
        self.launchAtLogin = launchAtLogin
        self.playFeedbackSounds = playFeedbackSounds
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    public static let defaultCleanupPrompt = "Clean up the transcript without changing its meaning. Correct punctuation, mistakes, and hesitations. Return only the final text."

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, stt, sttLanguage, sttPrompt, triggerMode, cleanupEnabled, cleanupProvider, cleanupFormat, cleanupPrompt, cleanupFailurePolicy, outputMode, launchAtLogin, playFeedbackSounds, hasCompletedOnboarding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        schemaVersion = decodedSchemaVersion
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
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        playFeedbackSounds = try container.decodeIfPresent(Bool.self, forKey: .playFeedbackSounds) ?? true
        // Existing installations predate onboarding and must not be interrupted
        // with it after updating to J7. A clean install uses the initializer.
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? (decodedSchemaVersion < Self.currentSchemaVersion)
    }
}

public enum OutputMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case clipboard
    case paste
    public var id: Self { self }
    public var title: String { self == .clipboard ? "Clipboard" : "Insert Automatically" }
}

public enum TextDeliveryResult: Equatable, Sendable {
    case copied
    case inserted
    case fallbackCopied(reason: String)
    case secureFieldCopied
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
            "Hold to Talk"
        case .toggle:
            "Press to Start/Stop"
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
            "Ready"
        case .requestingPermission:
            "Requesting microphone access…"
        case .recording:
            "Recording…"
        case .transcribing:
            "Transcribing…"
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

public protocol TextCleaning: Sendable {
    func clean(text: String, configuration: ProviderConfiguration, apiKey: String, format: CleanupAPIFormat, prompt: String) async throws -> String
}

@MainActor
public protocol TextDelivering: AnyObject {
    func copy(_ text: String)
    func copyAndPaste(_ text: String)
    func deliver(_ text: String, mode: OutputMode) -> TextDeliveryResult
}

@MainActor
public struct AppEnvironment {
    public let audioRecorder: any AudioRecording
    public let textDelivery: any TextDelivering
    public let transcriber: any SpeechTranscribing
    public let cleaner: any TextCleaning
    public let logStore: AppLogStore

    public init(
        audioRecorder: any AudioRecording,
        textDelivery: any TextDelivering,
        transcriber: any SpeechTranscribing,
        cleaner: any TextCleaning,
        logStore: AppLogStore
    ) {
        self.audioRecorder = audioRecorder
        self.textDelivery = textDelivery
        self.transcriber = transcriber
        self.cleaner = cleaner
        self.logStore = logStore
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
    public var onRecordingStarted: (() -> Void)?
    public var onRecordingStopped: (() -> Void)?

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
                let message = "Microphone access was denied. Allow Murmure in System Settings."
                self.environment.logStore.log("Error: \(message)")
                self.state = .error(message)
                return
            }
            guard self.activeSessionID == sessionID, self.state == .requestingPermission else { return }
            do {
                try self.environment.audioRecorder.start()
                self.environment.logStore.log("Recording started")
                self.onRecordingStarted?()
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
                self.environment.logStore.log("Error: \(safeLogMessage(for: error))")
                self.state = .error(error.localizedDescription)
            }
        }
    }

    public func dismissError() {
        guard case .error = state else { return }
        state = .idle
    }

    public func stopRecording(
        configuration: ProviderConfiguration,
        apiKey: String,
        prompt: String?,
        language: String?,
        cleanupEnabled: Bool,
        cleanupConfiguration: ProviderConfiguration,
        cleanupAPIKey: String,
        cleanupFormat: CleanupAPIFormat,
        cleanupPrompt: String,
        cleanupFailurePolicy: CleanupFailurePolicy,
        outputMode: OutputMode
    ) {
        guard state == .recording else { return }
        recordingWatchdog?.cancel()
        recordingWatchdog = nil
        let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartedAt = nil
        if duration < DictationTiming.minimumRecordingDuration {
            environment.audioRecorder.cancel()
            environment.logStore.log("Record ended")
            environment.logStore.log("Recording discarded: less than 250 ms")
            activeSessionID = nil
            state = .idle
            return
        }
        lastAudioURL = environment.audioRecorder.stop()
        environment.logStore.log("Record ended")
        onRecordingStopped?()
        guard let audioURL = lastAudioURL else {
            let message = "No audio file was produced."
            environment.logStore.log("Error: \(message)")
            state = .error(message)
            return
        }
        guard let sessionID = activeSessionID else {
            let message = "Recording session not found."
            environment.logStore.log("Error: \(message)")
            state = .error(message)
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
                let sizeInBytes = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? NSNumber)?.intValue ?? 0
                let sizeInKilobytes = Double(sizeInBytes) / 1024
                let host = configuration.endpointURL?.host ?? "configured endpoint"
                self.environment.logStore.log(String(format: "Sending %.1f kB to %@", sizeInKilobytes, host))
                let text = try await self.environment.transcriber.transcribe(
                    audioURL: audioURL,
                    configuration: configuration,
                    apiKey: apiKey,
                    prompt: prompt,
                    language: language
                )
                guard self.activeSessionID == sessionID else { return }
                self.environment.logStore.log("Received \(text.count) chars transcription")
                var finalText = text
                if cleanupEnabled {
                    let cleanupHost = cleanupConfiguration.endpointURL?.host ?? "configured endpoint"
                    self.environment.logStore.log("Sending transcription to \(cleanupHost)")
                    do {
                        let enhancedText = try await self.environment.cleaner.clean(
                            text: text,
                            configuration: cleanupConfiguration,
                            apiKey: cleanupAPIKey,
                            format: cleanupFormat,
                            prompt: cleanupPrompt
                        )
                        self.environment.logStore.log("Received \(enhancedText.count) chars enhanced transcription")
                        finalText = enhancedText
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        self.environment.logStore.log("Error: \(safeLogMessage(for: error))")
                        switch cleanupFailurePolicy {
                        case .useRawTranscript:
                            self.environment.logStore.log("Using raw transcription after cleanup error")
                        case .stop:
                            guard self.activeSessionID == sessionID else { return }
                            self.lastTranscript = text
                            self.activeSessionID = nil
                            self.lastAudioURL = nil
                            self.state = .error(error.localizedDescription)
                            return
                        }
                    }
                }
                guard self.activeSessionID == sessionID else { return }
                self.lastTranscript = finalText
                let deliveryResult = self.environment.textDelivery.deliver(finalText, mode: outputMode)
                switch deliveryResult {
                case .copied:
                    self.environment.logStore.log("Delivered transcription to clipboard")
                case .inserted:
                    self.environment.logStore.log("Inserted transcription in active field")
                case .fallbackCopied(let reason):
                    self.environment.logStore.log("Accessibility unavailable; copied to clipboard (\(reason))")
                case .secureFieldCopied:
                    self.environment.logStore.log("Secure field detected; copied to clipboard")
                }
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
                self.environment.logStore.log("Error: \(safeLogMessage(for: error))")
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
