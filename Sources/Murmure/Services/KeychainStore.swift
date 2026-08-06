import Foundation
import Security

enum KeychainStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status): "Erreur du Trousseau (\(status))."
        }
    }
}

final class KeychainStore {
    private let service: String

    init(service: String = "com.d9beuD.Murmure") {
        self.service = service
    }

    func read(profileID: UUID) throws -> String? {
        try read(profileIDs: [profileID])[profileID]
    }

    /// Reads several profile secrets with a single Keychain query.
    ///
    /// The result only contains profiles that have an existing, UTF-8 encoded
    /// value. Missing profiles are intentionally omitted.
    func read(profileIDs: [UUID]) throws -> [UUID: String] {
        let requestedIDs = Set(profileIDs)
        guard !requestedIDs.isEmpty else { return [:] }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [:] }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }

        let items: [[String: Any]]
        if let array = result as? [[String: Any]] {
            items = array
        } else if let item = result as? [String: Any] {
            // kSecMatchLimitAll normally returns an array, but accepting a
            // single dictionary keeps this method tolerant of Keychain mocks.
            items = [item]
        } else {
            return [:]
        }

        var secrets: [UUID: String] = [:]
        for item in items {
            guard
                let account = item[kSecAttrAccount as String] as? String,
                let profileID = UUID(uuidString: account),
                requestedIDs.contains(profileID),
                let data = item[kSecValueData as String] as? Data,
                let secret = String(data: data, encoding: .utf8)
            else { continue }
            secrets[profileID] = secret
        }
        return secrets
    }

    func save(_ secret: String, profileID: UUID) throws {
        if secret.isEmpty {
            try delete(profileID: profileID)
            return
        }
        let data = Data(secret.utf8)
        let query = baseQuery(profileID: profileID)
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
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

    func delete(profileID: UUID) throws {
        let status = SecItemDelete(baseQuery(profileID: profileID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainStoreError.unexpectedStatus(status) }
    }

    private func baseQuery(profileID: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: profileID.uuidString]
    }
}
