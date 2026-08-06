import AppKit

@MainActor
final class SoundFeedback {
    enum Event {
        case recordingStarted
        case recordingStopped
        case connectionTestSucceeded
        case error
    }

    func play(_ event: Event) {
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
