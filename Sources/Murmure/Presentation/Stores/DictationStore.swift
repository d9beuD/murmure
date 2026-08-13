import Foundation
import MurmureCore
import Observation

@MainActor
@Observable
final class DictationStore {
    let coordinator: DictationCoordinator
    private(set) var snapshot: DictationSnapshot

    init(coordinator: DictationCoordinator) {
        self.coordinator = coordinator
        snapshot = coordinator.snapshot
        coordinator.onSnapshot = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }

    var state: DictationState { snapshot.state }
    var lastAudioURL: URL? { snapshot.lastAudioURL }
    var lastTranscript: String? { snapshot.lastTranscript }
}
