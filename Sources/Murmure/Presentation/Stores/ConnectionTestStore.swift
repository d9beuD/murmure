import MurmureCore
import Observation

@MainActor
@Observable
final class ConnectionTestStore {
    let coordinator: ConnectionTestCoordinator
    private(set) var snapshot: ConnectionTestSnapshot

    init(coordinator: ConnectionTestCoordinator) {
        self.coordinator = coordinator
        snapshot = coordinator.snapshot
        coordinator.onSnapshot = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
    }

    var state: ConnectionTestState { snapshot.state }
}
