import AppKit
import AVFoundation
import CoreGraphics
import Observation
import SwiftUI
@preconcurrency import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let dictation = Self("dictation")
}

enum TriggerMode: String, CaseIterable, Identifiable {
    case pushToTalk
    case toggle

    var id: Self { self }

    var title: String {
        switch self {
        case .pushToTalk:
            "Maintenir pour parler"
        case .toggle:
            "Appuyer pour démarrer/arrêter"
        }
    }
}

enum SpikeState: Equatable {
    case idle
    case recording
    case error(String)

    var title: String {
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
final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?

    func start() throws {
        guard recorder == nil else { return }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MurmureSpike", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.prepareToRecord()

        guard newRecorder.record() else {
            throw RecorderError.couldNotStart
        }

        recorder = newRecorder
        currentURL = url
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        return currentURL
    }

    func cancel() {
        recorder?.stop()
        recorder = nil

        if let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
        }

        currentURL = nil
    }

    func deleteLastCapture() {
        guard let currentURL else { return }
        try? FileManager.default.removeItem(at: currentURL)
        self.currentURL = nil
    }
}

enum RecorderError: LocalizedError {
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .couldNotStart:
            "Impossible de démarrer l’enregistrement. Vérifiez l’autorisation microphone."
        }
    }
}

enum TextDelivery {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func copyAndPaste(_ text: String) {
        copy(text)

        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyCodeV: CGKeyCode = 9
        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: true
        )
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: false
        )

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

@MainActor
@Observable
final class SpikeModel {
    var mode: TriggerMode = .pushToTalk
    private(set) var state: SpikeState = .idle
    private(set) var lastAudioURL: URL?

    let audioRecorder = AudioRecorder()
    private var globalShortcutIsDown = false

    init() {
        KeyboardShortcuts.onKeyDown(for: .dictation) { [weak self] in
            Task { @MainActor in
                self?.handleKeyDown()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .dictation) { [weak self] in
            Task { @MainActor in
                self?.handleKeyUp()
            }
        }
    }

    func handleKeyDown() {
        guard !globalShortcutIsDown else { return }
        globalShortcutIsDown = true

        switch mode {
        case .pushToTalk:
            startRecording()
        case .toggle:
            if state == .recording {
                stopRecording()
            } else {
                startRecording()
            }
        }
    }

    func handleKeyUp() {
        globalShortcutIsDown = false

        if mode == .pushToTalk, state == .recording {
            stopRecording()
        }
    }

    func startRecording() {
        guard state != .recording else { return }

        do {
            try audioRecorder.start()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stopRecording() {
        guard state == .recording else { return }
        lastAudioURL = audioRecorder.stop()
        state = .idle
    }

    func cancelRecording() {
        audioRecorder.cancel()
        state = .idle
    }

    func copyTestText() {
        TextDelivery.copy("Murmure — test presse-papiers")
    }

    func pasteTestText() {
        TextDelivery.copyAndPaste("Murmure — test insertion")
    }

    func deleteLastCapture() {
        audioRecorder.deleteLastCapture()
        lastAudioURL = nil
    }
}

struct MenuContent: View {
    @Bindable var model: SpikeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(model.state.title, systemImage: model.state == .recording ? "record.circle.fill" : "waveform")
                .font(.headline)

            Picker("Mode", selection: $model.mode) {
                ForEach(TriggerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Divider()

            if model.state == .recording {
                Button("Arrêter") {
                    model.stopRecording()
                }

                Button("Annuler", role: .cancel) {
                    model.cancelRecording()
                }
            } else {
                Button("Démarrer") {
                    model.startRecording()
                }
            }

            Divider()

            Button("Copier un texte de test") {
                model.copyTestText()
            }

            Button("Insérer un texte de test") {
                model.pasteTestText()
            }

            if let lastAudioURL = model.lastAudioURL {
                Text(lastAudioURL.path)
                    .font(.caption)
                    .textSelection(.enabled)

                Button("Supprimer la capture") {
                    model.deleteLastCapture()
                }
            }

            Divider()

            SettingsLink {
                Label("Réglages du raccourci", systemImage: "gear")
            }

            Button("Quitter Murmure") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}

struct SettingsView: View {
    @Bindable var model: SpikeModel

    var body: some View {
        Form {
            Section("Raccourci global") {
                KeyboardShortcuts.Recorder("Raccourci :", name: .dictation)

                Picker("Mode", selection: $model.mode) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Spike J0") {
                Text("Le raccourci écoute les événements keyDown et keyUp même lorsque Murmure n’est pas au premier plan.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 260)
        .padding()
    }
}

@main
struct MurmureSpikeApp: App {
    @State private var model = SpikeModel()

    var body: some Scene {
        MenuBarExtra("Murmure", systemImage: "waveform") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
