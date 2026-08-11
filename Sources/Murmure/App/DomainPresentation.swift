import MurmureCore

extension AuthenticationMode {
    var title: String {
        switch self {
        case .bearer: "Bearer"
        case .apiKey: "API Key"
        case .none: "None"
        }
    }
}

extension CleanupAPIFormat {
    var title: String {
        switch self {
        case .responses: "Responses API"
        case .chatCompletions: "Chat Completions"
        }
    }
}

extension CleanupFailurePolicy {
    var title: String {
        switch self {
        case .useRawTranscript: "Use Raw Transcript"
        case .stop: "Stop with an Error"
        }
    }
}

extension OutputMode {
    var title: String { self == .clipboard ? "Clipboard" : "Insert Automatically" }
}

extension TriggerMode {
    var title: String {
        switch self {
        case .pushToTalk: "Hold to Talk"
        case .toggle: "Press to Start/Stop"
        }
    }
}

extension DictationFailure {
    var title: String {
        switch self {
        case .microphonePermissionDenied:
            "Microphone access was denied. Allow Murmure in System Settings."
        case .recordingFailed(let message), .transcriptionFailed(let message), .cleanupFailed(let message):
            message
        case .audioUnavailable:
            "No audio file was produced."
        case .sessionUnavailable:
            "Recording session not found."
        }
    }
}

extension DictationState {
    var title: String {
        switch self {
        case .idle: "Ready"
        case .requestingPermission: "Requesting microphone access…"
        case .recording: "Recording…"
        case .transcribing: "Transcribing…"
        case .error(let failure): failure.title
        }
    }
}

extension ConnectionTestState {
    var title: String {
        switch self {
        case .idle: "Ready to test the STT connection."
        case .requestingPermission: "Requesting microphone access…"
        case .recording: "Recording test audio…"
        case .testing: "Sending the recording to the provider…"
        case .succeeded(let characterCount): "Connection verified: received \(characterCount) characters."
        case .failed(let failure):
            switch failure {
            case .microphonePermissionDenied:
                "Microphone access was denied. Allow Murmure in System Settings."
            case .recordingFailed(let message), .transcriptionFailed(let message):
                message
            case .insufficientAudio:
                "Record at least one short phrase before running the test."
            }
        }
    }
}

extension PermissionStatus {
    var title: String {
        switch self {
        case .granted: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not allowed yet"
        }
    }
}
