import Foundation
import Security

enum KeychainStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): "Keychain error (\(status))."
        }
    }
}

final class KeychainStore {
    private let service: String
    private let secretsAccount = "api-keys"

    init(service: String = "com.d9beuD.Murmure") {
        self.service = service
    }

    func read(profileID: UUID) throws -> String? {
        try read(profileIDs: [profileID])[profileID]
    }

    /// Reads the requested secrets from one Keychain item.
    ///
    /// Earlier releases stored one item per profile. They are read only when
    /// the consolidated item does not exist yet, then migrated for subsequent
    /// launches.
    func read(profileIDs: [UUID]) throws -> [UUID: String] {
        let requestedIDs = Set(profileIDs)
        guard !requestedIDs.isEmpty else { return [:] }

        if let secrets = try readSecretsItem() {
            return secrets.filter { requestedIDs.contains($0.key) }
        }

        let legacySecrets = try readLegacySecrets(profileIDs: requestedIDs)
        if !legacySecrets.isEmpty {
            try save(legacySecrets)
        }
        return legacySecrets
    }

    func save(_ secrets: [UUID: String]) throws {
        let encodedSecrets = Dictionary(uniqueKeysWithValues: secrets.compactMap { profileID, secret in
            secret.isEmpty ? nil : (profileID.uuidString, secret)
        })
        let query = secretsQuery()

        if encodedSecrets.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw KeychainStoreError.unexpectedStatus(status)
            }
            return
        }

        let data = try JSONEncoder().encode(encodedSecrets)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(addStatus) }
        } else if status != errSecSuccess {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func readSecretsItem() throws -> [UUID: String]? {
        let query = secretsQuery().merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard
            let data = item as? Data,
            let encodedSecrets = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }

        var secrets: [UUID: String] = [:]
        for (account, secret) in encodedSecrets {
            guard let profileID = UUID(uuidString: account) else { continue }
            secrets[profileID] = secret
        }
        return secrets
    }

    private func readLegacySecrets(profileIDs: Set<UUID>) throws -> [UUID: String] {
        var secrets: [UUID: String] = [:]
        for profileID in profileIDs {
            let query = legacyQuery(profileID: profileID).merging([
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]) { _, new in new }
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound { continue }
            guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
            guard let data = item as? Data, let secret = String(data: data, encoding: .utf8) else { continue }
            secrets[profileID] = secret
        }
        return secrets
    }

    private func secretsQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: secretsAccount
        ]
    }

    private func legacyQuery(profileID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString
        ]
    }
}
