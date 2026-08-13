import MurmureCore
import Observation

@MainActor
@Observable
final class DictationSessionModel {
    let coordinator: DictationCoordinator
    let connectionTest: ConnectionTestModel

    init(coordinator: DictationCoordinator, connectionTest: ConnectionTestModel) {
        self.coordinator = coordinator
        self.connectionTest = connectionTest
    }
}
