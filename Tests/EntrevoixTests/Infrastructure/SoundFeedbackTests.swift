import Foundation
import Testing
import AppKit
import EntrevoixCore
@testable import Entrevoix

@MainActor
@Suite("Sound feedback")
struct SoundFeedbackTests {
    @Test("prefers native dictation sounds and caches every cue")
    func prefersNativeDictationSounds() {
        let nativeStart = SoundCueSpy(result: true)
        let nativeStop = SoundCueSpy(result: true)
        let nativeCancel = SoundCueSpy(result: true)
        let fallbackStart = SoundCueSpy(result: true)
        let fallbackStop = SoundCueSpy(result: true)
        let fallbackCancel = SoundCueSpy(result: true)
        let success = SoundCueSpy(result: true)
        var loadedFiles: [String] = []
        var loadedNames: [String] = []
        var beepCount = 0

        let feedback = SoundFeedback(
            nativeSoundDirectory: URL(fileURLWithPath: "/fixture/AssistantServices/Resources", isDirectory: true),
            fileSoundLoader: { url in
                loadedFiles.append(url.lastPathComponent)
                switch url.lastPathComponent {
                case "dt-begin.caf": return nativeStart
                case "dt-confirm.caf": return nativeStop
                case "dt-cancel.caf": return nativeCancel
                default: return nil
                }
            },
            namedSoundLoader: { name in
                let name = String(name)
                loadedNames.append(name)
                switch name {
                case "Tink": return fallbackStart
                case "Pop": return fallbackStop
                case "Funk": return fallbackCancel
                case "Glass": return success
                default: return nil
                }
            },
            beep: { beepCount += 1 }
        )

        feedback.play(.recordingStarted)
        feedback.play(.recordingStopped)
        feedback.play(.recordingCancelled)
        feedback.play(.connectionTestSucceeded)

        #expect(loadedFiles == ["dt-begin.caf", "dt-confirm.caf", "dt-cancel.caf"])
        #expect(loadedNames == ["Tink", "Pop", "Funk", "Glass"])
        #expect(nativeStart.playCount == 1)
        #expect(nativeStop.playCount == 1)
        #expect(nativeCancel.playCount == 1)
        #expect(fallbackStart.playCount == 0)
        #expect(fallbackStop.playCount == 0)
        #expect(fallbackCancel.playCount == 0)
        #expect(success.playCount == 1)
        #expect(beepCount == 0)
    }

    @Test("uses named fallbacks when native dictation sounds are unavailable")
    func usesNamedFallbacks() {
        let fallbackStart = SoundCueSpy(result: true)
        let fallbackStop = SoundCueSpy(result: true)
        let fallbackCancel = SoundCueSpy(result: true)
        let success = SoundCueSpy(result: true)
        var beepCount = 0

        let feedback = SoundFeedback(
            nativeSoundDirectory: URL(fileURLWithPath: "/fixture/AssistantServices/Resources", isDirectory: true),
            fileSoundLoader: { _ in nil },
            namedSoundLoader: { name in
                switch String(name) {
                case "Tink": return fallbackStart
                case "Pop": return fallbackStop
                case "Funk": return fallbackCancel
                case "Glass": return success
                default: return nil
                }
            },
            beep: { beepCount += 1 }
        )

        feedback.play(.recordingStarted)
        feedback.play(.recordingStopped)
        feedback.play(.recordingCancelled)
        feedback.play(.connectionTestSucceeded)

        #expect(fallbackStart.playCount == 1)
        #expect(fallbackStop.playCount == 1)
        #expect(fallbackCancel.playCount == 1)
        #expect(success.playCount == 1)
        #expect(beepCount == 0)
    }

    @Test("falls back to the system beep when both cues fail")
    func beepsWhenCuesFail() {
        let native = SoundCueSpy(result: false)
        let fallback = SoundCueSpy(result: false)
        var beepCount = 0

        let feedback = SoundFeedback(
            nativeSoundDirectory: URL(fileURLWithPath: "/fixture/AssistantServices/Resources", isDirectory: true),
            fileSoundLoader: { _ in native },
            namedSoundLoader: { _ in fallback },
            beep: { beepCount += 1 }
        )

        feedback.play(.recordingStarted)

        #expect(native.playCount == 1)
        #expect(fallback.playCount == 1)
        #expect(beepCount == 1)
    }

    @Test("uses the system beep for errors")
    func usesBeepForErrors() {
        var beepCount = 0
        let feedback = SoundFeedback(
            nativeSoundDirectory: URL(fileURLWithPath: "/fixture/AssistantServices/Resources", isDirectory: true),
            fileSoundLoader: { _ in nil },
            namedSoundLoader: { _ in nil },
            beep: { beepCount += 1 }
        )

        feedback.play(.error)

        #expect(beepCount == 1)
    }
}

@MainActor
private final class SoundCueSpy: SoundCuePlaying {
    let result: Bool
    private(set) var playCount = 0

    init(result: Bool) {
        self.result = result
    }

    func play() -> Bool {
        playCount += 1
        return result
    }
}
