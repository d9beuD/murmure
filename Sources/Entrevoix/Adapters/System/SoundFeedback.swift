import AppKit
import EntrevoixCore

@MainActor
final class SoundFeedback: FeedbackPlaying {
    func play(_ event: FeedbackEvent) {
        let name: NSSound.Name
        switch event {
        case .recordingStarted:
            name = NSSound.Name("Tink")
        case .recordingStopped:
            name = NSSound.Name("Pop")
        case .connectionTestSucceeded:
            name = NSSound.Name("Glass")
        case .error:
            NSSound.beep()
            return
        }
        if NSSound(named: name)?.play() != true {
            NSSound.beep()
        }
    }
}
