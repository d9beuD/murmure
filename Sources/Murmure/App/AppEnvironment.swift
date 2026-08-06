import MurmureCore

@MainActor
enum LiveEnvironment {
    static func make() -> AppEnvironment {
        AppEnvironment(
            audioRecorder: AudioRecorder(),
            textDelivery: TextDelivery(),
            transcriber: OpenAITranscriptionService(),
            cleaner: OpenAITextCleanupService(),
            logStore: AppLogStore()
        )
    }
}
