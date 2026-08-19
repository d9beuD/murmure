import Foundation
import EntrevoixCore
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
final class PreferencesStore {
    static let debounceDuration: Duration = .milliseconds(400)

    private(set) var preferences: AppPreferences

    /// The complete secret set is held only in memory and is always written as a
    /// complete map. This avoids deleting keys belonging to unselected profiles.
    private(set) var providerSecrets: [UUID: String]

    var sttAPIKey: String {
        get { apiKey(for: preferences.selectedSTTProviderID) }
        set { setAPIKey(newValue, for: preferences.selectedSTTProviderID) }
    }

    var cleanupAPIKey: String {
        get { apiKey(for: preferences.selectedTTTProviderID) }
        set { setAPIKey(newValue, for: preferences.selectedTTTProviderID) }
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

        let ids = initialPreferences.providerCatalog.compactMap { $0.id.remoteID }
        let legacyIDs = Array(initialPreferences.secretMigrationCopies.values)
        providerSecrets = (try? keychain.read(profileIDs: ids + legacyIDs)) ?? [:]
        for (newID, oldID) in initialPreferences.secretMigrationCopies where providerSecrets[newID] == nil {
            providerSecrets[newID] = providerSecrets[oldID]
        }
    }

    func update(
        _ newPreferences: AppPreferences,
        to policy: PreferencesPersistencePolicy = .debounced
    ) {
        preferences = newPreferences
        schedulePreferencesSave(policy: policy)
    }

    func updateSTTAPIKey(_ value: String, to policy: PreferencesPersistencePolicy = .debounced) { setAPIKey(value, for: preferences.selectedSTTProviderID, to: policy) }

    func updateCleanupAPIKey(_ value: String, to policy: PreferencesPersistencePolicy = .debounced) { setAPIKey(value, for: preferences.selectedTTTProviderID, to: policy) }

    func apiKey(for identifier: ProviderIdentifier?) -> String {
        guard let id = identifier?.remoteID else { return "" }
        return providerSecrets[id] ?? ""
    }

    func setAPIKey(_ value: String, for identifier: ProviderIdentifier?, to policy: PreferencesPersistencePolicy = .debounced) {
        guard let id = identifier?.remoteID else { return }
        providerSecrets[id] = value
        scheduleSecretsSave(policy: policy)
    }

    /// Deletes the Keychain value before mutating the catalogue. The caller can
    /// safely leave its preferences untouched if the system rejects the write.
    func removeProviderSecret(_ id: UUID) -> Bool {
        var next = providerSecrets
        next.removeValue(forKey: id)
        do {
            try keychain.save(next)
            providerSecrets = next
            persistenceError = nil
            return true
        } catch {
            persistenceError = .keychainSaveFailed
            return false
        }
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
            try keychain.save(providerSecrets)
            persistenceError = nil
        } catch {
            persistenceError = .keychainSaveFailed
        }
    }
}
