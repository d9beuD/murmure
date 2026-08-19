import EntrevoixCore
import XCTest
@testable import Entrevoix

final class UpdateStoreTests: XCTestCase {
    @MainActor
    func testStartsWithPersistedChannelAndConfirmsIncreasingRisk() {
        let preferencesStore = PreferencesStoreSpy(preferences: AppPreferences(updateChannel: .stable))
        let preferences = PreferencesStore(
            preferencesStore: preferencesStore,
            keychain: SecretStoreSpy(),
            initialPreferences: preferencesStore.preferences
        )
        let updater = UpdateServiceSpy()
        let store = UpdateStore(preferencesModel: preferences, updater: updater)

        XCTAssertEqual(updater.startedChannel, .stable)
        store.requestChannel(.releaseCandidate)
        XCTAssertEqual(store.selectedChannel, .stable)
        XCTAssertTrue(store.isConfirmationPresented)
        XCTAssertEqual(store.pendingChannel, .releaseCandidate)

        store.confirmPendingChannelChange()
        XCTAssertEqual(store.selectedChannel, .releaseCandidate)
        XCTAssertEqual(preferencesStore.saved.last?.updateChannel, .releaseCandidate)
        XCTAssertEqual(updater.setChannels, [.releaseCandidate])
    }

    @MainActor
    func testCancelLeavesChannelAndLowerRiskChangesAreImmediate() {
        let preferencesStore = PreferencesStoreSpy(preferences: AppPreferences(updateChannel: .development))
        let preferences = PreferencesStore(
            preferencesStore: preferencesStore,
            keychain: SecretStoreSpy(),
            initialPreferences: preferencesStore.preferences
        )
        let updater = UpdateServiceSpy()
        let store = UpdateStore(preferencesModel: preferences, updater: updater)

        store.requestChannel(.stable)
        XCTAssertEqual(store.selectedChannel, .stable)
        XCTAssertFalse(store.isConfirmationPresented)

        store.requestChannel(.development)
        XCTAssertTrue(store.isConfirmationPresented)
        store.cancelPendingChannelChange()
        XCTAssertEqual(store.selectedChannel, .stable)
        XCTAssertNil(store.pendingChannel)
        XCTAssertFalse(store.isConfirmationPresented)

        store.checkForUpdates()
        XCTAssertEqual(updater.checkCount, 1)
    }

    @MainActor
    func testReleaseCandidateToDevelopmentRequiresConfirmation() {
        let preferencesStore = PreferencesStoreSpy(preferences: AppPreferences(updateChannel: .releaseCandidate))
        let preferences = PreferencesStore(
            preferencesStore: preferencesStore,
            keychain: SecretStoreSpy(),
            initialPreferences: preferencesStore.preferences
        )
        let updater = UpdateServiceSpy()
        let store = UpdateStore(preferencesModel: preferences, updater: updater)

        store.requestChannel(.development)

        XCTAssertEqual(store.selectedChannel, .releaseCandidate)
        XCTAssertTrue(store.isConfirmationPresented)
        XCTAssertEqual(store.pendingChannel, .development)

        store.confirmPendingChannelChange()

        XCTAssertEqual(store.selectedChannel, .development)
        XCTAssertEqual(preferencesStore.saved.last?.updateChannel, .development)
        XCTAssertEqual(updater.setChannels, [.development])
    }
}

@MainActor
private final class UpdateServiceSpy: ApplicationUpdating {
    private(set) var startedChannel: UpdateChannel?
    private(set) var setChannels: [UpdateChannel] = []
    private(set) var checkCount = 0

    func start(channel: UpdateChannel) { startedChannel = channel }
    func setChannel(_ channel: UpdateChannel) { setChannels.append(channel) }
    func checkForUpdates() { checkCount += 1 }
}
