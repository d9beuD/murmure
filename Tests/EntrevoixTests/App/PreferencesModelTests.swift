import Foundation
import XCTest
@testable import Entrevoix
import EntrevoixCore

final class PreferencesStoreTests: XCTestCase {
    @MainActor
    func testPreferencesAndSecretsHaveIndependentPersistence() {
        let store = PreferencesStoreSpy()
        let keychain = SecretStoreSpy()
        let model = PreferencesStore(
            preferencesStore: store,
            keychain: keychain,
            initialPreferences: AppPreferences()
        )

        var updated = model.preferences
        updated.playFeedbackSounds.toggle()
        model.update(updated, to: .immediate)

        XCTAssertEqual(store.saved.count, 1)
        XCTAssertTrue(keychain.saves.isEmpty)

        model.updateSTTAPIKey("secret", to: .debounced)
        XCTAssertTrue(keychain.saves.isEmpty)
        model.flushPendingWrites()

        XCTAssertTrue(keychain.saves.last?.values.contains("secret") == true)
        XCTAssertEqual(store.saved.last?.cleanupPromptMode, .localizedDefault)
    }

    @MainActor
    func testDebouncedWritesCanBeFlushedAndSuperseded() {
        let store = PreferencesStoreSpy()
        let keychain = SecretStoreSpy()
        let model = PreferencesStore(
            preferencesStore: store,
            keychain: keychain,
            initialPreferences: AppPreferences()
        )

        var first = model.preferences
        first.playFeedbackSounds = false
        model.update(first)
        var second = first
        second.launchAtLogin = true
        model.update(second)

        XCTAssertTrue(store.saved.isEmpty)
        model.flushPendingWrites()

        XCTAssertEqual(store.saved.count, 1)
        XCTAssertEqual(store.saved.first?.launchAtLogin, true)
        XCTAssertEqual(store.saved.first?.playFeedbackSounds, false)
    }

    @MainActor
    func testKeychainFailureIsGenericAndDoesNotExposeSecret() {
        let store = PreferencesStoreSpy()
        let keychain = SecretStoreSpy()
        keychain.saveError = AppStubError.failure
        let model = PreferencesStore(
            preferencesStore: store,
            keychain: keychain,
            initialPreferences: AppPreferences()
        )

        model.updateSTTAPIKey("super-secret", to: .immediate)

        XCTAssertEqual(model.persistenceError, .keychainSaveFailed)
        XCTAssertFalse(String(describing: model.persistenceError).contains("super-secret"))
    }
}
