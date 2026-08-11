import Foundation

@MainActor
public struct DictationDependencies {
    public let audioRecorder: any AudioRecording
    public let microphonePermission: any MicrophonePermissionRequesting
    public let textDelivery: any TextDelivering
    public let transcriber: any SpeechTranscribing
    public let cleaner: any TextCleaning
    public let logger: any LogWriting

    public init(
        audioRecorder: any AudioRecording,
        microphonePermission: any MicrophonePermissionRequesting,
        textDelivery: any TextDelivering,
        transcriber: any SpeechTranscribing,
        cleaner: any TextCleaning,
        logger: any LogWriting
    ) {
        self.audioRecorder = audioRecorder
        self.microphonePermission = microphonePermission
        self.textDelivery = textDelivery
        self.transcriber = transcriber
        self.cleaner = cleaner
        self.logger = logger
    }
}
