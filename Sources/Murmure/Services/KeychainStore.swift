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
        let query = baseQuery(profileID: profileID).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unexpectedStatus(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
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
