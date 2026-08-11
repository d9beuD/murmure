import AppKit
import KeyboardShortcuts
import MurmureCore
import SwiftUI

struct OnboardingView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    private let stepCount = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView(value: Double(step + 1), total: Double(stepCount))
                .accessibilityLabel("Step \(step + 1) of \(stepCount)")

            Group {
                switch step {
                case 0: welcome
                case 1: sttConfiguration
                case 2: connectionTest
                case 3: shortcut
                default: delivery
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step < stepCount - 1 {
                    Button("Next") {
                        model.savePreferences()
                        step += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(step == 1 && !isSTTConfigurationValid)
                } else {
                    Button("Finish") {
                        model.completeOnboarding()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 620, height: 500)
        .background(OnboardingWindowFocus())
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Welcome to Murmure", systemImage: "waveform")
                .font(.largeTitle.bold())
            Text("Murmure records your voice locally, then sends the short audio file to your chosen STT provider. A second provider can then clean up the text if you enable that option.")
            Text("API keys stay in the macOS Keychain. Temporary audio files are deleted after dictation. Murmure has no servers or user accounts of its own.")
                .foregroundStyle(.secondary)
            Label("You can change all of these choices later in Settings.", systemImage: "gear")
                .font(.callout)
        }
    }

    private var sttConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription connection")
                .font(.title2.bold())
            Text("Enter the OpenAI-compatible endpoint and STT model to use.")
                .foregroundStyle(.secondary)
            TextField("Endpoint", text: $model.preferences.stt.baseURL)
            TextField("Path", text: $model.preferences.stt.path)
            TextField("Model", text: $model.preferences.stt.model)
            Picker("Authentication", selection: $model.preferences.stt.authentication) {
                ForEach(AuthenticationMode.allCases) { Text($0.title).tag($0) }
            }
            if model.preferences.stt.authentication != .none {
                SecureField("API key", text: $model.sttAPIKey)
            }
            if model.preferences.stt.authentication == .apiKey {
                TextField("Header name", text: $model.preferences.stt.customHeaderName)
            }
            if let endpoint = model.preferences.stt.endpointURL {
                Label(endpoint.absoluteString, systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label("The endpoint must start with http:// or https://.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var connectionTest: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test the connection")
                .font(.title2.bold())
            Text("This test is optional: speak a short phrase, then Murmure will send it to your STT provider. The test transcription is not retained.")
                .foregroundStyle(.secondary)
            ConnectionTestControls(model: model)
            if model.microphonePermission != .granted {
                Button("Allow Microphone Access") {
                    model.requestMicrophonePermission()
                }
            }
        }
    }

    private var shortcut: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Global shortcut")
                .font(.title2.bold())
            Text("Choose the shortcut that will trigger Murmure, even when another app is in the foreground.")
                .foregroundStyle(.secondary)
            KeyboardShortcuts.Recorder("Shortcut:", name: .dictation)
            Picker("Mode", selection: Binding(
                get: { model.mode },
                set: { model.setMode($0) }
            )) {
                ForEach(TriggerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        }
    }

    private var delivery: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delivery and preferences")
                .font(.title2.bold())
            Picker("Dictation output", selection: $model.preferences.outputMode) {
                ForEach(OutputMode.allCases) { Text($0.title).tag($0) }
            }
            if model.preferences.outputMode == .paste {
                Text("Automatic insertion requires Accessibility permission. Without it, the text will be copied to the clipboard.")
                    .foregroundStyle(.secondary)
                if model.accessibilityPermission != .granted {
                    Button("Allow Automatic Insertion") {
                        model.requestAccessibilityPermission()
                    }
                }
            }
            Toggle("Launch Murmure at login", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            Toggle("Play a sound when dictation starts and ends", isOn: $model.preferences.playFeedbackSounds)
        }
    }

    private var isSTTConfigurationValid: Bool {
        guard model.preferences.stt.endpointURL != nil else { return false }
        guard !model.preferences.stt.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return model.preferences.stt.authentication == .none || !model.sttAPIKey.isEmpty
    }
}

private struct OnboardingWindowFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
