import AppKit
import KeyboardShortcuts
import MurmureCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.title(locale: model.interfaceLocale), systemImage: section.systemImageName)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:
                    GeneralSettingsView(model: model)
                case .stt:
                    STTSettingsView(model: model)
                case .cleanup:
                    CleanupSettingsView(model: model)
                case .prompts:
                    PromptLibraryView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, idealWidth: 920, minHeight: 520, idealHeight: 700)
        .onChange(of: model.preferences) { _, _ in model.savePreferences() }
        .onChange(of: model.sttAPIKey) { _, _ in model.savePreferences() }
        .onChange(of: model.cleanupAPIKey) { _, _ in model.savePreferences() }
        .background(SettingsWindowFocus())
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case stt
    case cleanup
    case prompts

    var id: Self { self }

    var systemImageName: String {
        switch self {
        case .general: "gearshape"
        case .stt: "waveform"
        case .cleanup: "wand.and.stars"
        case .prompts: "text.badge.checkmark"
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .general: MurmureLocalization.text("settings.general", defaultValue: "General", locale: locale)
        case .stt: MurmureLocalization.text("settings.stt", defaultValue: "STT Transcription", locale: locale)
        case .cleanup: MurmureLocalization.text("settings.ttt", defaultValue: "TTT Cleanup", locale: locale)
        case .prompts: MurmureLocalization.text("settings.prompts", defaultValue: "Prompts", locale: locale)
        }
    }
}

private struct GeneralSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        let locale = model.interfaceLocale
        Form {
            Section(MurmureLocalization.text("settings.general", defaultValue: "General", locale: locale)) {
                Picker(MurmureLocalization.text("settings.interface_language", defaultValue: "Interface language", locale: locale), selection: Binding(
                    get: { model.preferences.interfaceLanguage },
                    set: { model.setInterfaceLanguage($0) }
                )) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(language.title(locale: locale)).tag(language)
                    }
                }
                Toggle(MurmureLocalization.text("settings.launch_at_login", defaultValue: "Launch Murmure at login", locale: locale), isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle(MurmureLocalization.text("settings.play_feedback", defaultValue: "Play a sound when dictation starts and ends", locale: locale), isOn: $model.preferences.playFeedbackSounds)
                if let launchAtLoginError = model.launchAtLoginError {
                    Label(launchAtLoginError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            Section(MurmureLocalization.text("settings.global_shortcut", defaultValue: "Global Shortcut", locale: locale)) {
                KeyboardShortcuts.Recorder(MurmureLocalization.text("field.shortcut", defaultValue: "Shortcut:", locale: locale), name: .dictation)
                Picker(MurmureLocalization.text("menu.mode", defaultValue: "Mode", locale: locale), selection: Binding(
                    get: { model.mode },
                    set: { model.setMode($0) }
                )) {
                    ForEach(TriggerMode.allCases) { mode in
                        Text(mode.title(locale: locale)).tag(mode)
                    }
                }
            }

            Section(MurmureLocalization.text("settings.delivery", defaultValue: "Delivery", locale: locale)) {
                Picker(MurmureLocalization.text("field.output", defaultValue: "Output", locale: locale), selection: $model.preferences.outputMode) {
                    ForEach(OutputMode.allCases) { Text($0.title(locale: locale)).tag($0) }
                }
            }

            PermissionsSettings(model: model)

            Section(MurmureLocalization.text("settings.about", defaultValue: "About", locale: locale)) {
                Text(MurmureLocalization.text("settings.version", defaultValue: "Murmure 0.1.0 — MIT License", locale: locale))
                Link(MurmureLocalization.text("settings.source_code", defaultValue: "Source code on GitHub", locale: locale), destination: URL(string: "https://github.com/d9beuD/murmure")!)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct PermissionsSettings: View {
    @Bindable var model: AppModel

    var body: some View {
        let locale = model.interfaceLocale
        Section(MurmureLocalization.text("settings.permissions", defaultValue: "Permissions", locale: locale)) {
            permissionRow(MurmureLocalization.text("permission.microphone", defaultValue: "Microphone", locale: locale), status: model.microphonePermission, locale: locale)
            if model.microphonePermission != .granted {
                Button(MurmureLocalization.text("permission.allow_microphone", defaultValue: "Allow Microphone Access", locale: locale)) { model.requestMicrophonePermission() }
            }
            permissionRow(MurmureLocalization.text("permission.accessibility", defaultValue: "Accessibility", locale: locale), status: model.accessibilityPermission, locale: locale)
            if model.accessibilityPermission != .granted {
                Button(MurmureLocalization.text("permission.allow_accessibility", defaultValue: "Allow Automatic Insertion", locale: locale)) { model.requestAccessibilityPermission() }
            }
            Button(MurmureLocalization.text("permission.refresh", defaultValue: "Refresh Permissions", locale: locale)) { model.refreshPermissions() }
            Text(MurmureLocalization.text("permission.accessibility_insertion_hint", defaultValue: "Accessibility permission is only required for automatic insertion. Without it, Murmure uses the clipboard.", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func permissionRow(_ name: String, status: PermissionStatus, locale: Locale) -> some View {
        HStack {
            Text(name)
            Spacer()
            Label(status.title(locale: locale), systemImage: status == .granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(status == .granted ? .green : .orange)
        }
        .accessibilityLabel(MurmureLocalization.permissionStatus(name: name, status: status.title(locale: locale), locale: locale))
    }
}

private struct STTSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        let locale = model.interfaceLocale
        Form {
            Section(MurmureLocalization.text("settings.stt", defaultValue: "STT Transcription", locale: locale)) {
                TextField(MurmureLocalization.text("field.name", defaultValue: "Name", locale: locale), text: $model.preferences.stt.name)
                TextField(MurmureLocalization.text("field.endpoint", defaultValue: "Endpoint", locale: locale), text: $model.preferences.stt.baseURL)
                TextField(MurmureLocalization.text("field.path", defaultValue: "Path", locale: locale), text: $model.preferences.stt.path)
                TextField(MurmureLocalization.text("field.model", defaultValue: "Model", locale: locale), text: $model.preferences.stt.model)
                TextField(MurmureLocalization.text("field.stt_language_optional", defaultValue: "Language (optional)", locale: locale), text: $model.preferences.sttLanguage)
                TextField(MurmureLocalization.text("field.context_prompt_optional", defaultValue: "Context prompt (optional)", locale: locale), text: $model.preferences.sttPrompt)
                Picker(MurmureLocalization.text("field.authentication", defaultValue: "Authentication", locale: locale), selection: $model.preferences.stt.authentication) {
                    ForEach(AuthenticationMode.allCases) { Text($0.title(locale: locale)).tag($0) }
                }
                if model.preferences.stt.authentication != .none {
                    SecureField(MurmureLocalization.text("field.api_key", defaultValue: "API key", locale: locale), text: $model.sttAPIKey)
                    if model.preferences.stt.authentication == .apiKey {
                        TextField(MurmureLocalization.text("field.header_name", defaultValue: "Header name", locale: locale), text: $model.preferences.stt.customHeaderName)
                    }
                }
                providerValidation(for: model.preferences.stt, locale: locale)
                ConnectionTestControls(model: model)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct CleanupSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        let locale = model.interfaceLocale
        Form {
            Section(MurmureLocalization.text("settings.ttt", defaultValue: "TTT Cleanup", locale: locale)) {
                Toggle(MurmureLocalization.text("settings.enable_cleanup", defaultValue: "Enable cleanup", locale: locale), isOn: $model.preferences.cleanupEnabled)
                if model.preferences.cleanupEnabled {
                    if model.preferences.cleanupPrompts.isEmpty {
                        Label(MurmureLocalization.text("prompts.none_warning", defaultValue: "No prompt is available. Add or reset a prompt before enabling cleanup.", locale: locale), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    Picker(MurmureLocalization.text("prompts.active", defaultValue: "Active prompt", locale: locale), selection: Binding<UUID?>(
                        get: { model.preferences.activeCleanupPromptID },
                        set: { model.setActiveCleanupPrompt($0) }
                    )) {
                        Text(MurmureLocalization.text("prompts.none", defaultValue: "None", locale: locale)).tag(Optional<UUID>.none)
                        ForEach(model.preferences.cleanupPrompts) { prompt in
                            Label(prompt.name, systemImage: prompt.systemImageName).tag(Optional(prompt.id))
                        }
                    }
                    TextField(MurmureLocalization.text("field.endpoint", defaultValue: "Endpoint", locale: locale), text: $model.preferences.cleanupProvider.baseURL)
                    TextField(MurmureLocalization.text("field.path", defaultValue: "Path", locale: locale), text: $model.preferences.cleanupProvider.path)
                    TextField(MurmureLocalization.text("field.model", defaultValue: "Model", locale: locale), text: $model.preferences.cleanupProvider.model)
                    Picker(MurmureLocalization.text("field.authentication", defaultValue: "Authentication", locale: locale), selection: $model.preferences.cleanupProvider.authentication) {
                        ForEach(AuthenticationMode.allCases) { Text($0.title(locale: locale)).tag($0) }
                    }
                    Picker(MurmureLocalization.text("field.format", defaultValue: "Format", locale: locale), selection: $model.preferences.cleanupFormat) {
                        ForEach(CleanupAPIFormat.allCases) { Text($0.title(locale: locale)).tag($0) }
                    }
                    if model.preferences.cleanupProvider.authentication != .none {
                        SecureField(MurmureLocalization.text("field.api_key", defaultValue: "API key", locale: locale), text: $model.cleanupAPIKey)
                    }
                    if model.preferences.cleanupProvider.authentication == .apiKey {
                        TextField(MurmureLocalization.text("field.header_name", defaultValue: "Header name", locale: locale), text: $model.preferences.cleanupProvider.customHeaderName)
                    }
                    Picker(MurmureLocalization.text("cleanup.on_failure", defaultValue: "On failure", locale: locale), selection: $model.preferences.cleanupFailurePolicy) {
                        ForEach(CleanupFailurePolicy.allCases) { Text($0.title(locale: locale)).tag($0) }
                    }
                    providerValidation(for: model.preferences.cleanupProvider, locale: locale)
                }
            }
            Section {
                Text(MurmureLocalization.text("prompts.settings_hint", defaultValue: "Manage prompt names, icons, and instructions in the Prompts section.", locale: locale))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct PromptLibraryView: View {
    @Bindable var model: AppModel
    @State private var selectedPromptID: UUID?
    @State private var editorPromptID: UUID?
    @State private var draft: CleanupPrompt?
    @State private var originalDraft: CleanupPrompt?
    @State private var pendingSelection: UUID?
    @State private var showDiscardConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showResetConfirmation = false
    @State private var error: CleanupPromptValidationError?

    init(model: AppModel) {
        self.model = model
        _selectedPromptID = State(initialValue: model.preferences.activeCleanupPromptID ?? model.preferences.cleanupPrompts.first?.id)
    }

    private var isDirty: Bool { draft != originalDraft }

    var body: some View {
        let locale = model.interfaceLocale
        VStack(spacing: 0) {
            HStack {
                Picker(MurmureLocalization.text("prompts.active", defaultValue: "Active prompt", locale: locale), selection: Binding<UUID?>(
                    get: { model.preferences.activeCleanupPromptID },
                    set: { model.setActiveCleanupPrompt($0) }
                )) {
                    Text(MurmureLocalization.text("prompts.none", defaultValue: "None", locale: locale)).tag(Optional<UUID>.none)
                    ForEach(model.preferences.cleanupPrompts) { prompt in
                        Label(prompt.name, systemImage: prompt.systemImageName).tag(Optional(prompt.id))
                    }
                }
                Spacer()
                Button { addPrompt() } label: { Label(MurmureLocalization.text("prompts.add", defaultValue: "Add", locale: locale), systemImage: "plus") }
                    .disabled(isDirty)
                Button(role: .destructive) { showDeleteConfirmation = true } label: { Label(MurmureLocalization.text("prompts.delete", defaultValue: "Delete", locale: locale), systemImage: "trash") }
                    .disabled(editorPromptID == nil)
                Button {
                    if model.cleanupPromptLibraryDiffersFromDefault {
                        showResetConfirmation = true
                    } else {
                        model.resetPromptLibrary()
                        ensureEditorSelection()
                    }
                } label: { Label(MurmureLocalization.text("prompts.reset", defaultValue: "Reset List", locale: locale), systemImage: "arrow.counterclockwise") }
                    .disabled(isDirty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            HSplitView {
                List(selection: $selectedPromptID) {
                    ForEach(model.preferences.cleanupPrompts) { prompt in
                        Label(prompt.name, systemImage: prompt.systemImageName)
                            .tag(Optional(prompt.id))
                    }
                    if model.preferences.cleanupPrompts.isEmpty {
                        Text(MurmureLocalization.text("prompts.none", defaultValue: "No prompts saved", locale: locale))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 220, idealWidth: 260)

                if draft != nil {
                    PromptEditor(
                        draft: Binding(get: { draft! }, set: { draft = $0 }),
                        error: $error,
                        onSave: { _ = saveDraft() },
                        onCancel: discardDraft,
                        locale: locale
                    )
                    .frame(minWidth: 420, idealWidth: 560)
                } else {
                    ContentUnavailableView(
                        MurmureLocalization.text("prompts.select", defaultValue: "Select a prompt", locale: locale),
                        systemImage: "text.badge.checkmark"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear { ensureEditorSelection() }
        .onChange(of: selectedPromptID) { _, newValue in
            guard newValue != editorPromptID else { return }
            if isDirty {
                pendingSelection = newValue
                selectedPromptID = editorPromptID
                showDiscardConfirmation = true
            } else {
                beginEditing(newValue)
            }
        }
        .alert(MurmureLocalization.text("prompts.unsaved_title", defaultValue: "Unsaved changes", locale: locale), isPresented: $showDiscardConfirmation) {
            Button(MurmureLocalization.text("action.save", defaultValue: "Save", locale: locale)) {
                if saveDraft() { beginEditing(pendingSelection); pendingSelection = nil }
            }
            Button(MurmureLocalization.text("action.discard", defaultValue: "Discard", locale: locale), role: .destructive) {
                discardDraft()
                beginEditing(pendingSelection)
                pendingSelection = nil
            }
            Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) { pendingSelection = nil }
        } message: {
            Text(MurmureLocalization.text("prompts.unsaved_message", defaultValue: "Save your changes before leaving this prompt?", locale: locale))
        }
        .alert(MurmureLocalization.text("prompts.delete_title", defaultValue: "Delete prompt?", locale: locale), isPresented: $showDeleteConfirmation) {
            Button(MurmureLocalization.text("prompts.delete", defaultValue: "Delete", locale: locale), role: .destructive) { deletePrompt() }
            Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) { }
        }
        .alert(MurmureLocalization.text("prompts.reset_title", defaultValue: "Reset prompt list?", locale: locale), isPresented: $showResetConfirmation) {
            Button(MurmureLocalization.text("prompts.reset", defaultValue: "Reset List", locale: locale), role: .destructive) {
                model.resetPromptLibrary()
                ensureEditorSelection()
            }
            Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) { }
        } message: {
            Text(MurmureLocalization.text("prompts.reset_message", defaultValue: "This replaces the current prompt list with the localized example prompt.", locale: locale))
        }
    }

    private func ensureEditorSelection() {
        let id = selectedPromptID ?? model.preferences.cleanupPrompts.first?.id
        selectedPromptID = id
        beginEditing(id)
    }

    private func beginEditing(_ id: UUID?) {
        editorPromptID = id
        draft = id.flatMap { promptID in model.preferences.cleanupPrompts.first { $0.id == promptID } }
        originalDraft = draft
        error = nil
    }

    private func addPrompt() {
        selectedPromptID = nil
        editorPromptID = nil
        originalDraft = nil
        draft = CleanupPrompt(name: "", systemImageName: "sparkles", instructions: "")
        error = nil
    }

    @discardableResult
    private func saveDraft() -> Bool {
        guard let draft else { return true }
        if let error = model.saveCleanupPrompt(draft) {
            self.error = error
            return false
        }
        editorPromptID = draft.id
        selectedPromptID = draft.id
        originalDraft = model.preferences.cleanupPrompts.first { $0.id == draft.id }
        self.draft = originalDraft
        error = nil
        return true
    }

    private func discardDraft() {
        draft = originalDraft
        error = nil
    }

    private func deletePrompt() {
        guard let editorPromptID else { return }
        model.deleteCleanupPrompt(id: editorPromptID)
        selectedPromptID = model.preferences.activeCleanupPromptID ?? model.preferences.cleanupPrompts.first?.id
        beginEditing(selectedPromptID)
    }
}

private struct PromptEditor: View {
    @Binding var draft: CleanupPrompt
    @Binding var error: CleanupPromptValidationError?
    let onSave: () -> Void
    let onCancel: () -> Void
    let locale: Locale

    var body: some View {
        Form {
            Section(MurmureLocalization.text("prompts.details", defaultValue: "Prompt details", locale: locale)) {
                TextField(MurmureLocalization.text("field.name", defaultValue: "Name", locale: locale), text: $draft.name)
                Picker(MurmureLocalization.text("prompts.icon", defaultValue: "Icon", locale: locale), selection: $draft.systemImageName) {
                    ForEach(PromptIcon.allCases) { icon in
                        Label(icon.label(locale: locale), systemImage: icon.rawValue).tag(icon.rawValue)
                    }
                }
            }
            Section(MurmureLocalization.text("prompts.instructions", defaultValue: "Instructions", locale: locale)) {
                TextEditor(text: $draft.instructions)
                    .font(.body)
                    .frame(minHeight: 220)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 1))
                if let error {
                    Label(error.message(locale: locale), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            HStack {
                Spacer()
                Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), action: onCancel)
                Button(MurmureLocalization.text("action.save", defaultValue: "Save", locale: locale), action: onSave)
                    .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private enum PromptIcon: String, CaseIterable, Identifiable {
    case wandAndStars = "wand.and.stars"
    case sparkles
    case textBadgeCheckmark = "text.badge.checkmark"
    case docText = "doc.text"
    case envelope
    case message
    case briefcase
    case graduationcap
    case terminal
    case quoteBubble = "quote.bubble"

    var id: Self { self }

    func label(locale: Locale) -> String {
        switch self {
        case .wandAndStars: "Wand and stars"
        case .sparkles: "Sparkles"
        case .textBadgeCheckmark: "Checked text"
        case .docText: "Document"
        case .envelope: "Envelope"
        case .message: "Message"
        case .briefcase: "Briefcase"
        case .graduationcap: "Graduation cap"
        case .terminal: "Terminal"
        case .quoteBubble: "Quote bubble"
        }
    }
}

private extension CleanupPromptValidationError {
    func message(locale: Locale) -> String {
        switch self {
        case .emptyName: MurmureLocalization.text("prompts.error_name", defaultValue: "A prompt name is required.", locale: locale)
        case .duplicateName: MurmureLocalization.text("prompts.error_duplicate", defaultValue: "Prompt names must be unique.", locale: locale)
        case .emptyInstructions: MurmureLocalization.text("prompts.error_instructions", defaultValue: "Prompt instructions are required.", locale: locale)
        case .invalidIcon: MurmureLocalization.text("prompts.error_icon", defaultValue: "Choose an icon from the available palette.", locale: locale)
        }
    }
}

@ViewBuilder
private func providerValidation(for provider: ProviderConfiguration, locale: Locale) -> some View {
    if provider.endpointURL == nil {
        Label(MurmureLocalization.text("validation.invalid_url", defaultValue: "Invalid URL: use http:// or https://", locale: locale), systemImage: "exclamationmark.triangle")
            .foregroundStyle(.orange)
            .font(.caption)
    } else if provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Label(MurmureLocalization.text("validation.model_required", defaultValue: "A model is required.", locale: locale), systemImage: "exclamationmark.triangle")
            .foregroundStyle(.orange)
            .font(.caption)
    }
}

/// A menubar-only app is not automatically activated when its Settings scene opens.
private struct SettingsWindowFocus: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeMain()
            window.makeKey()
        }
    }
}
