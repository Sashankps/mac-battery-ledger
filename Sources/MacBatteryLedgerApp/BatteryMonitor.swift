import Foundation
import IOKit.ps
import Observation

@Observable
final class BatteryMonitor {
    private static let transientStateLimit: TimeInterval = 30
    private static let healthSampleInterval: TimeInterval = 60 * 60
    private static let healthSampleLimit = 720
    private static let refreshInterval: TimeInterval = 5

    private let reader: BatteryReading
    private let store: BatteryHistoryStore
    private var timer: Timer?
    private var powerNotificationSource: CFRunLoopSource?

    private(set) var snapshot: BatterySnapshot?
    private(set) var history: BatteryHistory

    init(reader: BatteryReading = BatteryReader(), store: BatteryHistoryStore = BatteryHistoryStore()) {
        self.reader = reader
        self.store = store
        history = store.load()
    }

    deinit {
        timer?.invalidate()
        if let powerNotificationSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerNotificationSource, .commonModes)
        }
    }

    func start() {
        guard timer == nil, powerNotificationSource == nil else { return }
        refresh()
        startPowerSourceNotifications()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 0.5
    }

    func refresh() {
        guard let nextSnapshot = reader.readSnapshot() else { return }
        snapshot = nextSnapshot
        fold(nextSnapshot)
    }

    private func startPowerSourceNotifications() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.refreshAfterPowerSourceChange()
            }
        }, context)?.takeRetainedValue() else {
            return
        }

        powerNotificationSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func refreshAfterPowerSourceChange() {
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.refresh()
        }
    }

    private func fold(_ snapshot: BatterySnapshot) {
        let previousHistory = history
        defer {
            if history != previousHistory {
                store.save(history)
            }
        }

        recordHealthSample(snapshot)
        let nextKind: BatterySessionKind = snapshot.isPluggedIn ? .charge : .discharge

        guard var active = history.activeSession else {
            history.activeSession = makeSession(kind: nextKind, from: snapshot)
            return
        }

        if active.kind != nextKind {
            active = endedSession(active, at: snapshot)
            if let restored = restoreSessionInterrupted(by: active, matching: nextKind, at: snapshot) {
                history.activeSession = restored
                return
            }

            appendCompleted(active)
            history.activeSession = makeSession(kind: nextKind, from: snapshot)
            return
        }

        active.endPercentage = snapshot.percentage
        active.endCycleCount = snapshot.cycleCount
        history.activeSession = active
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

    private func endedSession(_ session: BatterySession, at snapshot: BatterySnapshot) -> BatterySession {
        var session = session
        session.endDate = snapshot.updatedAt
        session.endPercentage = snapshot.percentage
        session.endCycleCount = snapshot.cycleCount
        return session
    }

    private func restoreSessionInterrupted(
        by interruption: BatterySession,
        matching kind: BatterySessionKind,
        at snapshot: BatterySnapshot
    ) -> BatterySession? {
        guard
            interruption.duration < Self.transientStateLimit,
            interruption.percentageDelta == 0,
            let previous = history.sessions.first,
            previous.kind == kind,
            previous.endDate == interruption.startDate
        else {
            return nil
        }

        history.sessions.removeFirst()
        var restored = previous
        restored.endDate = nil
        restored.endPercentage = snapshot.percentage
        restored.endCycleCount = snapshot.cycleCount
        return restored
    }

    private func appendCompleted(_ session: BatterySession) {
        guard session.duration >= 60 || abs(session.percentageDelta) > 0 else { return }
        history.sessions.insert(session, at: 0)
        if history.sessions.count > 80 {
            history.sessions.removeLast(history.sessions.count - 80)
        }
    }

    private func recordHealthSample(_ snapshot: BatterySnapshot) {
        guard snapshot.healthPercent != nil || snapshot.cycleCount != nil || snapshot.maxCapacity != nil else { return }

        let sample = BatteryHealthSample(from: snapshot)
        if let latest = history.healthSamples.first {
            let valuesChanged = latest.cycleCount != sample.cycleCount
                || latest.healthPercent != sample.healthPercent
                || latest.maxCapacity != sample.maxCapacity
                || latest.designCapacity != sample.designCapacity
            let isStale = snapshot.updatedAt.timeIntervalSince(latest.date) >= Self.healthSampleInterval
            guard valuesChanged || isStale else { return }
        }

        history.healthSamples.insert(sample, at: 0)
        if history.healthSamples.count > Self.healthSampleLimit {
            history.healthSamples.removeLast(history.healthSamples.count - Self.healthSampleLimit)
        }
    }
}
