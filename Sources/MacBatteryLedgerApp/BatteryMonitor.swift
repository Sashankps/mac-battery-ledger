import Foundation
import Observation

@Observable
final class BatteryMonitor {
    private let reader: BatteryReading
    private let store: BatteryHistoryStore
    private var timer: Timer?

    private(set) var snapshot: BatterySnapshot?
    private(set) var history: BatteryHistory

    init(reader: BatteryReading = BatteryReader(), store: BatteryHistoryStore = BatteryHistoryStore()) {
        self.reader = reader
        self.store = store
        history = store.load()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 6
    }

    func refresh() {
        guard let nextSnapshot = reader.readSnapshot() else { return }
        snapshot = nextSnapshot
        fold(nextSnapshot)
    }

    private func fold(_ snapshot: BatterySnapshot) {
        let nextKind: BatterySessionKind = snapshot.isPluggedIn ? .charge : .discharge

        guard var active = history.activeSession else {
            history.activeSession = makeSession(kind: nextKind, from: snapshot)
            store.save(history)
            return
        }

        if active.kind != nextKind {
            active.endDate = snapshot.updatedAt
            active.endPercentage = snapshot.percentage
            active.endCycleCount = snapshot.cycleCount
            appendCompleted(active)
            history.activeSession = makeSession(kind: nextKind, from: snapshot)
            store.save(history)
            return
        }

        active.endPercentage = snapshot.percentage
        active.endCycleCount = snapshot.cycleCount
        history.activeSession = active
        store.save(history)
    }

    private func makeSession(kind: BatterySessionKind, from snapshot: BatterySnapshot) -> BatterySession {
        BatterySession(
            id: UUID(),
            kind: kind,
            startDate: snapshot.updatedAt,
            endDate: nil,
            startPercentage: snapshot.percentage,
            endPercentage: snapshot.percentage,
            startCycleCount: snapshot.cycleCount,
            endCycleCount: snapshot.cycleCount
        )
    }

    private func appendCompleted(_ session: BatterySession) {
        guard session.duration >= 60 || abs(session.percentageDelta) > 0 else { return }
        history.sessions.insert(session, at: 0)
        if history.sessions.count > 80 {
            history.sessions.removeLast(history.sessions.count - 80)
        }
    }
}
