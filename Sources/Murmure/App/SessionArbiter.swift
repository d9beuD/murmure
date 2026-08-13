import MurmureCore

@MainActor
final class SessionArbiter: SessionArbitrating {
    private var activeLease: SessionLease?
    func acquire(_ kind: SessionKind) -> SessionLease? {
        guard activeLease == nil else { return nil }
        let lease = SessionLease(kind: kind)
        activeLease = lease
        return lease
    }
    func release(_ lease: SessionLease) {
        guard activeLease == lease else { return }
        activeLease = nil
    }
}
