import Foundation
import XCTest
@testable import Murmure

final class KeychainStoreTests: XCTestCase {
    private let service = "MurmureTests"

    func testSaveReadFilterUpdateAndDelete() throws {
        let access = MemoryKeychainAccess()
        let store = KeychainStore(service: service, access: access)
        let first = UUID()
        let second = UUID()

        try store.save([first: "first-key", second: ""])
        XCTAssertEqual(try store.read(profileIDs: [first, second]), [first: "first-key"])
        XCTAssertEqual(access.upserts.map(\.1), ["api-keys"])

        try store.save([first: "updated", second: "second-key"])
        XCTAssertEqual(try store.read(profileID: first), "updated")
        XCTAssertEqual(try store.read(profileIDs: [second]), [second: "second-key"])

        try store.save([:])
        XCTAssertEqual(access.deletes.map(\.1), ["api-keys"])
        XCTAssertEqual(try store.read(profileIDs: []), [:])
    }

    func testMalformedConsolidatedDataAndInvalidUUIDsAreIgnored() throws {
        let access = MemoryKeychainAccess()
        let store = KeychainStore(service: service, access: access)
        let requested = UUID()
        access.seed(Data("not-json".utf8), service: service, account: "api-keys")
        XCTAssertEqual(try store.read(profileIDs: [requested]), [:])

        let data = try JSONEncoder().encode([
            "invalid": "ignored",
            requested.uuidString: "kept"
        ])
        access.seed(data, service: service, account: "api-keys")
        XCTAssertEqual(try store.read(profileIDs: [requested]), [requested: "kept"])
    }

    func testLegacyItemsAreReadAndMigrated() throws {
        let access = MemoryKeychainAccess()
        let store = KeychainStore(service: service, access: access)
        let first = UUID()
        let second = UUID()
        access.seed(Data("legacy-key".utf8), service: service, account: first.uuidString)

        XCTAssertEqual(try store.read(profileIDs: [first, second]), [first: "legacy-key"])
        XCTAssertEqual(access.reads.first?.1, "api-keys")
        XCTAssertEqual(Set(access.reads.dropFirst().map(\.1)), Set([first.uuidString, second.uuidString]))
        let migratedData = try XCTUnwrap(access.data(service: service, account: "api-keys"))
        let migrated = try JSONDecoder().decode([String: String].self, from: migratedData)
        XCTAssertEqual(migrated, [first.uuidString: "legacy-key"])
    }

    func testBackendErrorsPropagateWithoutSecrets() {
        let access = MemoryKeychainAccess()
        access.readError = KeychainStoreError.unexpectedStatus(-50)
        let store = KeychainStore(service: service, access: access)

        XCTAssertThrowsError(try store.read(profileIDs: [UUID()])) { error in
            XCTAssertEqual(error.localizedDescription, "Keychain error (-50).")
            XCTAssertFalse(error.localizedDescription.contains("secret"))
        }

        let writeAccess = MemoryKeychainAccess()
        writeAccess.upsertError = KeychainStoreError.unexpectedStatus(-25299)
        XCTAssertThrowsError(try KeychainStore(service: service, access: writeAccess).save([UUID(): "key"]))

        let deleteAccess = MemoryKeychainAccess()
        deleteAccess.deleteError = KeychainStoreError.unexpectedStatus(-25300)
        XCTAssertThrowsError(try KeychainStore(service: service, access: deleteAccess).save([:]))
    }
}
