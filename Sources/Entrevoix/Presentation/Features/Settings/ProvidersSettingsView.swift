import EntrevoixCore
import SwiftUI

struct ProvidersSettingsView: View {
    @Environment(ProviderStore.self) private var model
    @State private var selection: ProviderIdentifier?
    @State private var draft: RemoteProviderProfile?
    @State private var draftKey = ""
    @State private var validation: [ProviderValidationIssue] = []
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(model.providersSortedForDisplay) { entry in
                    Label(model.providerName(entry), systemImage: icon(for: entry))
                        .tag(Optional(entry.id))
                }
            }
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button(model.providerName(.apple)) { model.addAppleProvider(); selection = .apple }
                            .disabled(model.preferences.providerCatalog.contains { $0.id == .apple })
                        Button(model.providerName(.codex(CodexProviderProfile()))) { model.addCodexProvider(); selection = .codex }
                            .disabled(model.preferences.providerCatalog.contains { $0.id == .codex })
                        Button(text("provider.openai", "OpenAI")) { begin(model.newRemoteProvider(kind: .openAI)) }
                        Button(text("provider.openai_compatible", "OpenAI-compatible")) { begin(model.newRemoteProvider(kind: .openAICompatible)) }
                    } label: { Label(text("provider.add", "Add provider"), systemImage: "plus") }
                }
            }
        } detail: {
            detail
        }
        .onChange(of: selection) { _, id in
            if id == .codex { draft = nil; return }
            guard let profile = model.preferences.remoteProfile(for: id) else { draft = nil; return }
            begin(profile)
        }
        .alert(text("provider.remove_title", "Remove provider?"), isPresented: $showDeleteConfirmation) {
            Button(text("action.remove", "Remove"), role: .destructive) {
                if let selection {
                    if selection == .codex { model.removeCodexProvider() } else { _ = model.removeProvider(selection) }
                    self.selection = nil; draft = nil
                }
            }
            Button(text("action.cancel", "Cancel"), role: .cancel) {}
        } message: {
            Text(text("provider.remove_message", "Its API key is removed first. Selected STT and TTT capabilities will be deselected."))
        }
    }

    @ViewBuilder private var detail: some View {
        if selection == .apple {
            Form {
                Section(model.providerName(.apple)) {
                    Label(text("provider.apple_privacy", "Speech transcription and text cleanup run on this Mac. No audio or text is sent to a network provider."), systemImage: "lock.fill")
                    Label(text("provider.apple_assets", "Speech availability is checked before recording. Download required speech assets from the STT settings."), systemImage: "waveform")
                    Label(text("provider.apple_intelligence", "Apple Intelligence availability is checked before cleanup."), systemImage: "apple.intelligence")
                }
                Section {
                    Button(text("provider.remove_apple", "Remove Apple provider"), role: .destructive) { showDeleteConfirmation = true }
            }
            }.padding()
        } else if selection == .codex, let profile = model.preferences.provider(for: .codex)?.codexProfile {
            CodexProviderEditor(
                model: model,
                profile: profile,
                onDelete: { showDeleteConfirmation = true }
            )
        } else if let draft {
            RemoteProviderEditor(model: model, draft: binding(for: draft), apiKey: $draftKey, validation: validation, onLoadModels: { model.loadModels(for: $0) }, onSave: save, onCancel: cancel, onDelete: { showDeleteConfirmation = true })
        } else {
            ContentUnavailableView(text("provider.none_selected", "No provider selected"), systemImage: "network", description: Text(text("provider.empty_description", "Add a local Apple or remote provider to begin.")))
        }
    }

    private func begin(_ profile: RemoteProviderProfile) {
        draft = profile
        draftKey = model.apiKey(for: .remote(profile.id))
        validation = []
        selection = .remote(profile.id)
    }

    private func binding(for profile: RemoteProviderProfile) -> Binding<RemoteProviderProfile> {
        Binding(get: { draft ?? profile }, set: { draft = $0; validation = [] })
    }

    private func save() {
        guard let draft else { return }
        validation = model.saveRemoteProvider(draft, apiKey: draftKey)
    }

    private func cancel() {
        if let selection, model.preferences.provider(for: selection) == nil { self.selection = nil }
        draft = nil; validation = []
    }

    private func icon(for entry: ProviderCatalogEntry) -> String {
        switch entry {
        case .apple: "apple.logo"
        case .codex: "cpu"
        case .remote(let profile): profile.kind == .openAI ? "circle.grid.2x2" : "network"
        }
    }

    private func text(_ key: String, _ fallback: String) -> String {
        EntrevoixLocalization.text(key, defaultValue: fallback, locale: model.interfaceLocale)
    }
}

private struct CodexProviderEditor: View {
    @Bindable var model: ProviderStore
    let profile: CodexProviderProfile
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section(model.providerName(.codex(CodexProviderProfile()))) {
                Label(text("codex.description", "Use your ChatGPT account to improve transcriptions."), systemImage: "person.crop.circle")
                connectionControls
            }
            Section(text("codex.cleanup", "Text cleanup")) {
                Picker(text("codex.model", "Model"), selection: Binding(
                    get: { model.preferences.provider(for: .codex)?.codexProfile?.model ?? profile.model },
                    set: { model.setCodexModel($0) }
                )) {
                    ForEach(CodexModel.allCases) { Text($0.rawValue).tag($0) }
                }
                Text(text("codex.ttt_only", "OpenAI (Codex) is available for text cleanup only. Choose a separate speech-to-text provider."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button(text("action.remove", "Remove"), role: .destructive, action: onDelete)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func text(_ key: String, _ fallback: String) -> String {
        EntrevoixLocalization.text(key, defaultValue: fallback, locale: model.interfaceLocale)
    }

    @ViewBuilder private var connectionControls: some View {
        switch model.codexConnectionState {
        case .disconnected:
            Button(text("codex.connect", "Connect ChatGPT"), action: model.connectCodex).buttonStyle(.borderedProminent)
        case .connecting:
            HStack { ProgressView(); Text(text("codex.connecting", "Connecting to ChatGPT…")) }
        case .connected:
            HStack {
                Label(text("codex.connected", "Connected"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Spacer()
                Button(text("codex.disconnect", "Disconnect"), action: model.disconnectCodex).buttonStyle(.bordered)
            }
        case .failed:
            HStack {
                Label(text("error.codex_connection_failed", "Could not connect to ChatGPT."), systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                Spacer()
                Button(text("codex.connect", "Connect ChatGPT"), action: model.connectCodex).buttonStyle(.bordered)
            }
        }
    }
}

private struct RemoteProviderEditor: View {
    @Bindable var model: ProviderStore
    @Binding var draft: RemoteProviderProfile
    @Binding var apiKey: String
    let validation: [ProviderValidationIssue]
    let onLoadModels: (RemoteProviderProfile) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section(draft.kind == .openAI ? text("provider.openai", "OpenAI") : text("provider.openai_compatible", "OpenAI-compatible")) {
                TextField(text("field.name", "Name"), text: $draft.name)
                TextField(text("field.base_url", "Base URL"), text: $draft.baseURL).disabled(draft.kind == .openAI)
                Picker(text("field.authentication", "Authentication"), selection: $draft.authentication) {
                    ForEach(AuthenticationMode.allCases) { Text($0.title(locale: model.interfaceLocale)).tag($0) }
                }.disabled(draft.kind == .openAI)
                if draft.authentication != .none {
                    SecureField(text("field.api_key", "API key"), text: $apiKey)
                    if draft.authentication == .apiKey { TextField(text("field.header_name", "Header name"), text: $draft.customHeaderName) }
                }
                if draft.kind == .openAICompatible { TextField(text("field.models_path", "Models path"), text: $draft.modelsPath) }
                Button(text("provider.load_models", "Load / Refresh models")) { onLoadModels(draft) }
                if let models = model.discoveredModels[draft.id], !models.isEmpty {
                    Menu(text("provider.use_loaded_model", "Use a loaded model")) { ForEach(models, id: \.self) { modelID in
                        Button(modelID) { if draft.stt != nil { draft.stt?.model = modelID } else { draft.ttt?.model = modelID } }
                    }}
                }
                if let message = model.modelDiscoveryError(for: draft.id) {
                    Text(message).font(.caption).foregroundStyle(.orange)
                }
            }
            Section(text("provider.capabilities", "Capabilities")) {
                Toggle(text("provider.speech_to_text", "Speech to text"), isOn: Binding(get: { draft.stt != nil }, set: { $0 ? (draft.stt = STTCapability()) : (draft.stt = nil) }))
                if draft.stt != nil {
                    TextField(text("field.stt_route", "STT route"), text: Binding(get: { draft.stt?.path ?? "" }, set: { draft.stt?.path = $0 })).disabled(draft.kind == .openAI)
                    TextField(text("field.stt_model", "STT model"), text: Binding(get: { draft.stt?.model ?? "" }, set: { draft.stt?.model = $0 }))
                }
                Toggle(text("provider.text_cleanup", "Text cleanup"), isOn: Binding(get: { draft.ttt != nil }, set: { $0 ? (draft.ttt = TTTCapability()) : (draft.ttt = nil) }))
                if draft.ttt != nil {
                    TextField(text("field.ttt_route", "TTT route"), text: Binding(get: { draft.ttt?.path ?? "" }, set: { draft.ttt?.path = $0 })).disabled(draft.kind == .openAI)
                    TextField(text("field.ttt_model", "TTT model"), text: Binding(get: { draft.ttt?.model ?? "" }, set: { draft.ttt?.model = $0 }))
                    Picker(text("field.ttt_api_format", "TTT API format"), selection: Binding(get: { draft.ttt?.format ?? .responses }, set: { draft.ttt?.format = $0 })) { ForEach(CleanupAPIFormat.allCases) { Text($0.title(locale: model.interfaceLocale)).tag($0) } }
                }
            }
            if let first = validation.first { Label(first.localizedProviderValidationTitle(locale: model.interfaceLocale), systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            HStack { Button(text("action.save", "Save"), action: onSave).buttonStyle(.borderedProminent); Button(text("action.cancel", "Cancel"), action: onCancel); Spacer(); Button(text("action.remove", "Remove"), role: .destructive, action: onDelete) }
        }
        .formStyle(.grouped).padding()
    }

    private func text(_ key: String, _ fallback: String) -> String {
        EntrevoixLocalization.text(key, defaultValue: fallback, locale: model.interfaceLocale)
    }
}

private extension ProviderValidationIssue {
    func localizedProviderValidationTitle(locale: Locale) -> String {
        switch self {
        case .missingName: EntrevoixLocalization.text("provider.validation_name", defaultValue: "A provider name is required.", locale: locale)
        case .duplicateName: EntrevoixLocalization.text("provider.validation_duplicate", defaultValue: "Provider names must be unique.", locale: locale)
        case .invalidEndpoint: EntrevoixLocalization.text("provider.validation_endpoint", defaultValue: "Enter a valid http:// or https:// URL.", locale: locale)
        case .missingCapability: EntrevoixLocalization.text("provider.validation_capability", defaultValue: "Select at least one capability.", locale: locale)
        case .missingRoute: EntrevoixLocalization.text("provider.validation_route", defaultValue: "A route is required for each capability.", locale: locale)
        case .missingModel: EntrevoixLocalization.text("provider.validation_model", defaultValue: "A model is required.", locale: locale)
        case .missingHeaderName: EntrevoixLocalization.text("provider.validation_header", defaultValue: "An authentication header name is required.", locale: locale)
        case .missingAPIKey: EntrevoixLocalization.text("provider.validation_api_key", defaultValue: "An API key is required for this authentication mode.", locale: locale)
        }
    }
}
