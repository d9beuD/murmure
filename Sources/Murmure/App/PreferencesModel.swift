import Foundation
import MurmureCore
import Observation

enum PreferencesPersistencePolicy: Sendable {
    case immediate
    case debounced
}

enum PreferencesPersistenceError: Error, Equatable {
    case keychainSaveFailed
}

@MainActor
@Observable
final class PreferencesModel {
    static let debounceDuration: Duration = .milliseconds(400)

    var preferences: AppPreferences {
        didSet { schedulePreferencesSave(policy: .debounced) }
    }

    var sttAPIKey: String {
        didSet { scheduleSecretsSave(policy: .debounced) }
    }

    var cleanupAPIKey: String {
        didSet { scheduleSecretsSave(policy: .debounced) }
    }

    private(set) var persistenceError: PreferencesPersistenceError?

    private let preferencesStore: any PreferencesStoring
    private let keychain: any SecretStoring
    private var preferencesSaveTask: Task<Void, Never>?
    private var secretsSaveTask: Task<Void, Never>?

    init(
        preferencesStore: any PreferencesStoring,
        keychain: any SecretStoring,
        initialPreferences: AppPreferences
    ) {
        self.preferencesStore = preferencesStore
        self.keychain = keychain
        preferences = initialPreferences

        let secrets = (try? keychain.read(profileIDs: [
            initialPreferences.stt.id,
            initialPreferences.cleanupProvider.id
        ])) ?? [:]
        sttAPIKey = secrets[initialPreferences.stt.id] ?? ""
        cleanupAPIKey = secrets[initialPreferences.cleanupProvider.id] ?? ""
    }

    func update(
        _ newPreferences: AppPreferences,
        to policy: PreferencesPersistencePolicy = .debounced
    ) {
        preferences = newPreferences
        schedulePreferencesSave(policy: policy)
    }

    func updateSTTAPIKey(_ value: String, to policy: PreferencesPersistencePolicy = .debounced) {
        sttAPIKey = value
        scheduleSecretsSave(policy: policy)
    }

    func updateCleanupAPIKey(_ value: String, to policy: PreferencesPersistencePolicy = .debounced) {
        cleanupAPIKey = value
        scheduleSecretsSave(policy: policy)
    }

    func flushPendingWrites() {
        preferencesSaveTask?.cancel()
        preferencesSaveTask = nil
        secretsSaveTask?.cancel()
        secretsSaveTask = nil
        persistPreferences()
        persistSecrets()
    }

    func savePreferencesImmediately() {
        preferencesSaveTask?.cancel()
        preferencesSaveTask = nil
        persistPreferences()
    }

    func saveSecretsImmediately() {
        secretsSaveTask?.cancel()
        secretsSaveTask = nil
        persistSecrets()
    }

    private func schedulePreferencesSave(policy: PreferencesPersistencePolicy) {
        preferencesSaveTask?.cancel()
        guard policy == .debounced else {
            persistPreferences()
            return
        }

        preferencesSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.debounceDuration)
            } catch {
                return
            }
            guard let self else { return }
            self.persistPreferences()
            self.preferencesSaveTask = nil
        }
    }

    private func scheduleSecretsSave(policy: PreferencesPersistencePolicy) {
        secretsSaveTask?.cancel()
        guard policy == .debounced else {
            persistSecrets()
            return
        }

        secretsSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.debounceDuration)
            } catch {
                return
            }
            guard let self else { return }
            self.persistSecrets()
            self.secretsSaveTask = nil
        }
    }

    private func persistPreferences() {
        var value = preferences
        value.schemaVersion = AppPreferences.currentSchemaVersion
        preferencesStore.save(value)
    }

    private func persistSecrets() {
        do {
            try keychain.save([
                preferences.stt.id: sttAPIKey,
                preferences.cleanupProvider.id: cleanupAPIKey
            ])
            persistenceError = nil
        } catch {
            persistenceError = .keychainSaveFailed
        }
    }
}
