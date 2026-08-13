import AppKit
import KeyboardShortcuts
import MurmureCore
import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var selection: SettingsSection? = .general
    @State private var promptNavigation = PromptLibraryNavigationState()

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { selection },
                set: { newSelection in
                    guard newSelection != selection else { return }
                    if selection == .prompts, newSelection != .prompts, promptNavigation.isDirty {
                        promptNavigation.pendingAction = .leaveSettings(newSelection)
                        promptNavigation.showUnsavedConfirmation = true
                    } else {
                        selection = newSelection
                        if newSelection != .prompts {
                            promptNavigation.discard()
                            promptNavigation.path.removeAll()
                        }
                    }
                }
            )) {
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
                    PromptLibraryView(model: model, state: promptNavigation) { newSelection in
                        selection = newSelection
                    }
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

enum SettingsSection: String, CaseIterable, Identifiable {
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
                Picker(MurmureLocalization.text("field.stt_language", defaultValue: "Transcription language", locale: locale), selection: Binding(
                    get: { model.preferences.sttLanguage },
                    set: { model.setSTTLanguage($0) }
                )) {
                    ForEach(TranscriptionLanguage.sortedForDisplay(locale: locale)) { language in
                        Text(language.title(locale: locale)).tag(language)
                    }
                }
                .pickerStyle(.menu)
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
            Section(MurmureLocalization.text("field.stt_favorite_languages", defaultValue: "Languages in the menu", locale: locale)) {
                ForEach(TranscriptionLanguage.sortedForDisplay(locale: locale, includingAutomatic: false)) { language in
                    Toggle(language.title(locale: locale), isOn: Binding(
                        get: { model.preferences.sttFavoriteLanguages.contains(language) },
                        set: { model.setSTTFavoriteLanguage(language, enabled: $0) }
                    ))
                    .toggleStyle(.checkbox)
                }
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

enum PromptDestination: Hashable {
    case edit(UUID, token: UUID)
    case create(UUID)
}

enum PromptPendingAction {
    case back
    case leaveSettings(SettingsSection?)
}

@MainActor
@Observable
final class PromptLibraryNavigationState {
    var path: [PromptDestination] = []
    var draft: CleanupPrompt?
    var originalDraft: CleanupPrompt?
    var validationError: CleanupPromptValidationError?
    var pendingAction: PromptPendingAction?
    var showUnsavedConfirmation = false
    var showDeleteConfirmation = false
    var showResetConfirmation = false

    var isDirty: Bool { draft != originalDraft }

    func openPrompt(_ id: UUID) {
        path.append(.edit(id, token: UUID()))
    }

    func beginEditing(_ id: UUID, model: AppModel) {
        guard draft?.id != id || originalDraft == nil else { return }
        draft = model.preferences.cleanupPrompts.first { $0.id == id }
        originalDraft = draft
        validationError = nil
    }

    func beginCreating(_ id: UUID) {
        guard draft?.id != id else { return }
        draft = CleanupPrompt(id: id, name: "", systemImageName: "sparkles", instructions: "")
        originalDraft = nil
        validationError = nil
    }

    @discardableResult
    func save(model: AppModel) -> Bool {
        guard let draft else { return true }
        if let validationError = model.saveCleanupPrompt(draft) {
            self.validationError = validationError
            return false
        }
        let savedDraft = model.preferences.cleanupPrompts.first { $0.id == draft.id }
        self.draft = savedDraft
        originalDraft = savedDraft
        self.validationError = nil
        return true
    }

    func discard() {
        draft = originalDraft
        validationError = nil
    }

    func resetTransientState() {
        path.removeAll()
        draft = nil
        originalDraft = nil
        validationError = nil
        pendingAction = nil
        showUnsavedConfirmation = false
        showDeleteConfirmation = false
        showResetConfirmation = false
    }
}

private struct PromptLibraryView: View {
    @Bindable var model: AppModel
    @Bindable var state: PromptLibraryNavigationState
    let onLeaveSettings: (SettingsSection?) -> Void

    var body: some View {
        let locale = model.interfaceLocale
        NavigationStack(path: $state.path) {
            PromptListPage(model: model, state: state)
                .navigationDestination(for: PromptDestination.self) { destination in
                    PromptEditorPage(model: model, state: state, destination: destination)
                }
        }
        .alert(MurmureLocalization.text("prompts.unsaved_title", defaultValue: "Unsaved changes", locale: locale), isPresented: $state.showUnsavedConfirmation) {
            Button(MurmureLocalization.text("action.save", defaultValue: "Save", locale: locale)) {
                guard state.save(model: model) else {
                    state.showUnsavedConfirmation = true
                    return
                }
                resolvePendingAction(discard: false)
            }
            Button(MurmureLocalization.text("action.discard", defaultValue: "Discard", locale: locale), role: .destructive) {
                resolvePendingAction(discard: true)
            }
            Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) {
                state.pendingAction = nil
            }
        } message: {
            Text(MurmureLocalization.text("prompts.unsaved_message", defaultValue: "Save your changes before leaving this prompt?", locale: locale))
        }
        .onChange(of: model.preferences.cleanupPrompts) { _, prompts in
            guard let draftID = state.draft?.id,
                  prompts.contains(where: { $0.id == draftID }) else { return }
            if !state.isDirty {
                state.beginEditing(draftID, model: model)
            }
        }
    }

    private func resolvePendingAction(discard: Bool) {
        if discard { state.discard() }
        let action = state.pendingAction
        state.pendingAction = nil
        switch action {
        case .back:
            state.path.removeLast()
        case .leaveSettings(let section):
            state.resetTransientState()
            onLeaveSettings(section)
        case nil:
            break
        }
    }
}

private struct PromptListPage: View {
    @Bindable var model: AppModel
    @Bindable var state: PromptLibraryNavigationState

    var body: some View {
        let locale = model.interfaceLocale
        List {
            Section {
                Picker(MurmureLocalization.text("prompts.active", defaultValue: "Active prompt", locale: locale), selection: Binding<UUID?>(
                    get: { model.preferences.activeCleanupPromptID },
                    set: { model.setActiveCleanupPrompt($0) }
                )) {
                    Text(MurmureLocalization.text("prompts.none", defaultValue: "None", locale: locale)).tag(Optional<UUID>.none)
                    ForEach(model.preferences.cleanupPrompts) { prompt in
                        Label(prompt.name, systemImage: prompt.systemImageName).tag(Optional(prompt.id))
                    }
                }
            }

            Section {
                if model.preferences.cleanupPrompts.isEmpty {
                    ContentUnavailableView(
                        MurmureLocalization.text("prompts.none", defaultValue: "No prompts saved", locale: locale),
                        systemImage: "text.badge.checkmark"
                    )
                } else {
                    ForEach(model.preferences.cleanupPrompts) { prompt in
                        Button {
                            state.openPrompt(prompt.id)
                        } label: {
                            HStack {
                                Label(prompt.name, systemImage: prompt.systemImageName)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }

            Section {
                Button {
                    if model.cleanupPromptLibraryDiffersFromDefault {
                        state.showResetConfirmation = true
                    } else {
                        model.resetPromptLibrary()
                    }
                } label: {
                    Label(MurmureLocalization.text("prompts.reset", defaultValue: "Reset List", locale: locale), systemImage: "arrow.counterclockwise")
                }
                .disabled(state.isDirty)
            }
        }
        .listStyle(.inset)
        .navigationTitle(MurmureLocalization.text("settings.prompts", defaultValue: "Prompts", locale: locale))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let id = UUID()
                    state.beginCreating(id)
                    state.path.append(.create(id))
                } label: {
                    Label(MurmureLocalization.text("prompts.add", defaultValue: "Add", locale: locale), systemImage: "plus")
                }
                .disabled(state.isDirty)
            }
        }
        .alert(MurmureLocalization.text("prompts.reset_title", defaultValue: "Reset prompt list?", locale: locale), isPresented: $state.showResetConfirmation) {
            Button(MurmureLocalization.text("prompts.reset", defaultValue: "Reset List", locale: locale), role: .destructive) {
                model.resetPromptLibrary()
            }
            Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) { }
        } message: {
            Text(MurmureLocalization.text("prompts.reset_message", defaultValue: "This replaces the current prompt list with the localized example prompt.", locale: locale))
        }
    }
}

private struct PromptEditorPage: View {
    @Bindable var model: AppModel
    @Bindable var state: PromptLibraryNavigationState
    let destination: PromptDestination

    var body: some View {
        let locale = model.interfaceLocale
        editorContent(locale: locale)
        .navigationTitle(isExistingPrompt
            ? MurmureLocalization.text("prompts.edit_title", defaultValue: "Edit Prompt", locale: locale)
            : MurmureLocalization.text("prompts.new_title", defaultValue: "New Prompt", locale: locale))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: ToolbarItemPlacement.navigation) {
                Button(action: requestBack) {
                    Image(systemName: "chevron.left")
                        .accessibilityLabel(MurmureLocalization.text("action.back", defaultValue: "Back", locale: locale))
                }
            }
        }
        .onAppear {
            switch destination {
            case .edit(let id, _): state.beginEditing(id, model: model)
            case .create(let id): state.beginCreating(id)
            }
        }
        .alert(MurmureLocalization.text("prompts.delete_title", defaultValue: "Delete prompt?", locale: locale), isPresented: $state.showDeleteConfirmation) {
            Button(MurmureLocalization.text("prompts.delete", defaultValue: "Delete", locale: locale), role: .destructive) {
                deleteAndReturn()
            }
            Button(MurmureLocalization.text("action.cancel", defaultValue: "Cancel", locale: locale), role: .cancel) { }
        }
    }

    private var isExistingPrompt: Bool {
        if case .edit = destination { return true }
        return false
    }

    @ViewBuilder
    private func editorContent(locale: Locale) -> some View {
        if state.draft != nil {
            PromptEditor(
                draft: Binding(get: { state.draft! }, set: { state.draft = $0 }),
                error: $state.validationError,
                onSave: saveAndReturn,
                onCancel: requestCancel,
                onDelete: requestDelete,
                showsDelete: isExistingPrompt,
                locale: locale
            )
        } else {
            ContentUnavailableView(
                MurmureLocalization.text("prompts.select", defaultValue: "Select a prompt", locale: locale),
                systemImage: "text.badge.checkmark"
            )
        }
    }

    private func saveAndReturn() {
        guard state.save(model: model) else { return }
        state.path.removeLast()
    }

    private func requestCancel() {
        requestBack()
    }

    private func requestBack() {
        if state.isDirty {
            state.pendingAction = .back
            state.showUnsavedConfirmation = true
        } else {
            state.discard()
            state.path.removeLast()
        }
    }

    private func requestDelete() {
        state.showDeleteConfirmation = true
    }

    private func deleteAndReturn() {
        guard let id = state.draft?.id else { return }
        model.deleteCleanupPrompt(id: id)
        state.resetTransientState()
    }
}

private struct PromptEditor: View {
    @Binding var draft: CleanupPrompt
    @Binding var error: CleanupPromptValidationError?
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    let showsDelete: Bool
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
            if showsDelete {
                Section {
                    Button(role: .destructive, action: onDelete) {
                        Label(MurmureLocalization.text("prompts.delete", defaultValue: "Delete", locale: locale), systemImage: "trash")
                    }
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
