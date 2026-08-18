import AppKit
import EntrevoixCore

@MainActor
protocol SoundCuePlaying: AnyObject {
    func play() -> Bool
}

extension NSSound: SoundCuePlaying {}

@MainActor
final class SoundFeedback: FeedbackPlaying {
    private static let nativeSoundDirectory = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/AssistantServices.framework/Resources", isDirectory: true)

    private let nativeStartSound: (any SoundCuePlaying)?
    private let nativeStopSound: (any SoundCuePlaying)?
    private let nativeCancelSound: (any SoundCuePlaying)?
    private let startFallback: (any SoundCuePlaying)?
    private let stopFallback: (any SoundCuePlaying)?
    private let cancelFallback: (any SoundCuePlaying)?
    private let connectionTestSuccessSound: (any SoundCuePlaying)?
    private let beep: () -> Void

    convenience init() {
        self.init(
            nativeSoundDirectory: Self.nativeSoundDirectory,
            fileSoundLoader: { NSSound(contentsOf: $0, byReference: false) },
            namedSoundLoader: { NSSound(named: $0) },
            beep: { NSSound.beep() }
        )
    }

    init(
        nativeSoundDirectory: URL,
        fileSoundLoader: @escaping (URL) -> (any SoundCuePlaying)?,
        namedSoundLoader: @escaping (NSSound.Name) -> (any SoundCuePlaying)?,
        beep: @escaping () -> Void
    ) {
        nativeStartSound = fileSoundLoader(nativeSoundDirectory.appendingPathComponent("dt-begin.caf"))
        nativeStopSound = fileSoundLoader(nativeSoundDirectory.appendingPathComponent("dt-confirm.caf"))
        nativeCancelSound = fileSoundLoader(nativeSoundDirectory.appendingPathComponent("dt-cancel.caf"))
        startFallback = namedSoundLoader(NSSound.Name("Tink"))
        stopFallback = namedSoundLoader(NSSound.Name("Pop"))
        cancelFallback = namedSoundLoader(NSSound.Name("Funk"))
        connectionTestSuccessSound = namedSoundLoader(NSSound.Name("Glass"))
        self.beep = beep
    }

    func play(_ event: FeedbackEvent) {
        switch event {
        case .recordingStarted:
            play(nativeStartSound, fallback: startFallback)
        case .recordingStopped:
            play(nativeStopSound, fallback: stopFallback)
        case .recordingCancelled:
            play(nativeCancelSound, fallback: cancelFallback)
        case .connectionTestSucceeded:
            play(connectionTestSuccessSound, fallback: nil)
        case .error:
            beep()
        }
    }

    private func play(_ preferred: (any SoundCuePlaying)?, fallback: (any SoundCuePlaying)?) {
        if preferred?.play() == true {
            return
        }
        if fallback?.play() == true {
            return
        }
        beep()
    }
}
