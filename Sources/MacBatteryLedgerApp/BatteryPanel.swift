import SwiftUI

struct BatteryPanel: View {
    @Bindable var monitor: BatteryMonitor
    @State private var destination: BatteryPanelDestination?

    private var snapshot: BatterySnapshot? {
        monitor.snapshot
    }

    private var visibleSessions: [BatterySession] {
        var sessions = monitor.history.sessions
        if let active = monitor.history.activeSession {
            sessions.insert(active, at: 0)
        }
        return sessions
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let destination {
                ScrollView(showsIndicators: false) {
                    switch destination {
                    case .cycles:
                        CycleDetailView(snapshot: snapshot, sessions: visibleSessions)
                    case .health:
                        HealthDetailView(snapshot: snapshot, samples: monitor.history.healthSamples)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            } else {
                VStack(spacing: 14) {
                    if let snapshot {
                        HeroBatteryCard(snapshot: snapshot)
                        MetricGrid(snapshot: snapshot) { nextDestination in
                            destination = nextDestination
                        }
                    } else {
                        UnavailableCard()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    HistorySection(sessions: visibleSessions)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }

            if destination == nil {
                footer
            } else {
                detailFooter
            }
        }
        .background(PremiumStyle.panel)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            if destination != nil {
                Button {
                    destination = nil
                } label: {
                    ZStack {
                        Color.clear
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("Back to dashboard")
                .pointerCursor()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(destination?.title ?? "Battery Ledger")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PremiumStyle.ink)
                Text(destination?.subtitle(snapshot: snapshot) ?? snapshot?.powerStateLabel ?? "Reading Battery")
                    .font(PremiumStyle.smallFont)
                    .foregroundStyle(PremiumStyle.secondaryInk)
            }

            Spacer()

            if destination == nil {
                Button {
                    monitor.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("Refresh")
                .pointerCursor()
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Quit Battery Ledger")
            .pointerCursor()
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var detailFooter: some View {
        HStack {
            Circle()
                .fill(PremiumStyle.green)
                .frame(width: 7, height: 7)
            Text("Stats update with each battery refresh")
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk)
            Spacer()
            Button {
                monitor.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("Refresh")
            .pointerCursor()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(PremiumStyle.softPanel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PremiumStyle.line)
                .frame(height: 1)
        }
    }

    private var footer: some View {
        HStack {
            Circle()
                .fill(snapshot?.isPluggedIn == true ? PremiumStyle.green : PremiumStyle.graphite.opacity(0.65))
                .frame(width: 7, height: 7)
            Text(snapshot?.isPluggedIn == true ? "Power connected" : "Tracking discharge")
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk)
            Spacer()
            Text("Updates every 30s")
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk.opacity(0.75))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(PremiumStyle.softPanel)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PremiumStyle.line)
                .frame(height: 1)
        }
    }
}

private enum BatteryPanelDestination {
    case cycles
    case health

    var title: String {
        switch self {
        case .cycles:
            return "Cycle Control"
        case .health:
            return "Battery Health"
        }
    }

    func subtitle(snapshot: BatterySnapshot?) -> String {
        switch self {
        case .cycles:
            return snapshot?.cycleCount.map { "\($0) total cycles" } ?? "Cycle count unavailable"
        case .health:
            guard let snapshot else { return "Health unavailable" }
            return snapshot.healthPercent.map { "\($0)% capacity health" } ?? snapshot.healthLabel
        }
    }
}

private struct HeroBatteryCard: View {
    let snapshot: BatterySnapshot

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Charge")
                        .font(PremiumStyle.smallFont)
                        .foregroundStyle(PremiumStyle.secondaryInk)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(snapshot.percentage)")
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(PremiumStyle.ink)
                        Text("%")
                            .font(.system(size: 23, weight: .semibold, design: .rounded))
                            .foregroundStyle(PremiumStyle.secondaryInk)
                    }
                }

                Spacer()

                ZStack(alignment: .leading) {
                    BatteryOutline()
                        .stroke(PremiumStyle.ink.opacity(0.18), lineWidth: 2)
                        .frame(width: 96, height: 44)

                    BatteryFill(level: snapshot.percentage)
                        .fill(fillColor)
                        .frame(width: 96, height: 44)
                        .clipShape(BatteryOutline())

                    if snapshot.isCharging || snapshot.isPluggedIn {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 44)
                    }
                }
                .padding(.top, 4)
            }

            HStack(spacing: 10) {
                MiniStatusPill(title: "State", value: snapshot.powerStateLabel)
                MiniStatusPill(title: snapshot.isPluggedIn ? "To Full" : "Remaining", value: BatteryFormatters.timeRemaining(minutes: snapshot.timeRemainingMinutes))
            }
        }
        .glassCard()
    }

    private var fillColor: Color {
        if snapshot.percentage <= 20 {
            return PremiumStyle.red
        }
        if snapshot.percentage <= 45 {
            return PremiumStyle.amber
        }
        return PremiumStyle.green
    }
}

private struct MetricGrid: View {
    let snapshot: BatterySnapshot
    let onSelect: (BatteryPanelDestination) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            Button {
                onSelect(.cycles)
            } label: {
                MetricTile(title: "Cycles", value: snapshot.cycleCount.map(String.init) ?? "—", footnote: "open stats")
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("View cycle stats")
            .pointerCursor()

            Button {
                onSelect(.health)
            } label: {
                MetricTile(title: "Health", value: snapshot.healthPercent.map { "\($0)%" } ?? "—", footnote: "open stats")
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help("View health stats")
            .pointerCursor()

            MetricTile(title: "Capacity", value: capacityText, footnote: "full charge")
        }
    }

    private var capacityText: String {
        guard let maxCapacity = snapshot.maxCapacity else {
            return "—"
        }
        let ampHours = Double(maxCapacity) / 1000.0
        return String(format: "%.1f Ah", ampHours)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PremiumStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(footnote)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PremiumStyle.secondaryInk.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(PremiumStyle.softPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PremiumStyle.line, lineWidth: 1)
        }
    }
}

private struct CycleDetailView: View {
    let snapshot: BatterySnapshot?
    let sessions: [BatterySession]

    private var insights: CycleInsights {
        CycleInsights(snapshot: snapshot, sessions: sessions)
    }

    var body: some View {
        VStack(spacing: 12) {
            if snapshot == nil {
                EmptyDetailCard(
                    systemImage: "arrow.triangle.2.circlepath",
                    title: "Cycle data is unavailable",
                    message: "Open this on a MacBook with readable battery cycle data."
                )
            } else {
                DetailHeroCard(
                    systemImage: "dial.low.fill",
                    title: "Cycle Pressure",
                    value: insights.count.map(String.init) ?? "--",
                    label: insights.pressureLabel,
                    tint: insights.tint,
                    progress: insights.limitProgress
                )

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    DetailStatTile(title: "Cycle Budget", value: insights.remainingText, footnote: "left to \(CycleInsights.planningLimit)")
                    DetailStatTile(title: "Recorded Use", value: insights.loggedEquivalentText, footnote: "full-cycle equivalent")
                    DetailStatTile(title: "Pace", value: insights.monthlyPaceText, footnote: "cycles per 30 days")
                    DetailStatTile(title: "Deep Drains", value: "\(insights.deepDrainCount)", footnote: "35%+ drops logged")
                }

                InsightPanel(title: "Cycle Timeline") {
                    InsightRow(
                        systemImage: "calendar.badge.clock",
                        title: "Last cycle movement",
                        value: insights.lastCycleEventText,
                        subtitle: "\(insights.cycleEvents) cycle count changes in recorded history",
                        tint: PremiumStyle.graphite
                    )
                    InsightRow(
                        systemImage: "flag.checkered",
                        title: "Projected limit",
                        value: insights.projectedLimitText,
                        subtitle: "Based on the current recorded pace",
                        tint: insights.tint
                    )
                }

                InsightPanel(title: "Control Signals") {
                    InsightRow(
                        systemImage: "chart.xyaxis.line",
                        title: "Wear velocity",
                        value: insights.velocityLabel,
                        subtitle: insights.velocityDetail,
                        tint: insights.tint
                    )
                    InsightRow(
                        systemImage: "moon.zzz.fill",
                        title: "Drain profile",
                        value: insights.drainProfileLabel,
                        subtitle: insights.drainProfileDetail,
                        tint: PremiumStyle.amber
                    )
                }
            }
        }
    }
}

private struct HealthDetailView: View {
    let snapshot: BatterySnapshot?
    let samples: [BatteryHealthSample]

    private var insights: HealthInsights {
        HealthInsights(snapshot: snapshot, samples: samples)
    }

    var body: some View {
        VStack(spacing: 12) {
            if snapshot == nil {
                EmptyDetailCard(
                    systemImage: "heart.text.square",
                    title: "Health data is unavailable",
                    message: "Open this on a MacBook with readable battery health data."
                )
            } else {
                DetailHeroCard(
                    systemImage: "heart.circle.fill",
                    title: "Capacity Health",
                    value: insights.healthText,
                    label: insights.healthLabel,
                    tint: insights.tint,
                    progress: insights.healthProgress
                )

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    DetailStatTile(title: "Full Charge", value: insights.maxCapacityText, footnote: "usable capacity")
                    DetailStatTile(title: "Design", value: insights.designCapacityText, footnote: "factory capacity")
                    DetailStatTile(title: "Reserve Lost", value: insights.capacityLostText, footnote: "design gap")
                    DetailStatTile(title: "Temperature", value: insights.temperatureText, footnote: insights.temperatureFootnote)
                }

                InsightPanel(title: "Health Trend") {
                    InsightRow(
                        systemImage: "point.3.connected.trianglepath.dotted",
                        title: "Tracked baseline",
                        value: insights.baselineText,
                        subtitle: "\(samples.count) health snapshots stored",
                        tint: PremiumStyle.graphite
                    )
                    InsightRow(
                        systemImage: "waveform.path.ecg",
                        title: "Health drift",
                        value: insights.healthDriftText,
                        subtitle: insights.healthDriftDetail,
                        tint: insights.driftTint
                    )
                }

                InsightPanel(title: "Capacity Control") {
                    CapacityBar(title: "Current charge against full capacity", percent: insights.currentFillPercent)
                    InsightRow(
                        systemImage: "battery.100percent",
                        title: "Capacity headroom",
                        value: insights.headroomText,
                        subtitle: "Space between current charge and full charge",
                        tint: PremiumStyle.green
                    )
                }
            }
        }
    }
}

private struct DetailHeroCard: View {
    let systemImage: String
    let title: String
    let value: String
    let label: String
    let tint: Color
    let progress: Double

    var body: some View {
        VStack(spacing: 13) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.13))
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(tint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PremiumStyle.smallFont)
                        .foregroundStyle(PremiumStyle.secondaryInk)
                    Text(value)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(PremiumStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.12), in: Capsule())
            }

            ProgressMeter(progress: progress, tint: tint)
        }
        .glassCard()
    }
}

private struct DetailStatTile: View {
    let title: String
    let value: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PremiumStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(footnote)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(PremiumStyle.secondaryInk.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(PremiumStyle.softPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PremiumStyle.line, lineWidth: 1)
        }
    }
}

private struct InsightPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(PremiumStyle.titleFont)
                .foregroundStyle(PremiumStyle.ink)
            VStack(spacing: 8) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InsightRow: View {
    let systemImage: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PremiumStyle.secondaryInk)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(PremiumStyle.secondaryInk.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PremiumStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .background(PremiumStyle.softPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PremiumStyle.line, lineWidth: 1)
        }
    }
}

private struct CapacityBar: View {
    let title: String
    let percent: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(PremiumStyle.smallFont)
                    .foregroundStyle(PremiumStyle.secondaryInk)
                Spacer()
                Text(percent.map { "\($0)%" } ?? "--")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PremiumStyle.ink)
            }
            ProgressMeter(progress: Double(percent ?? 0) / 100.0, tint: PremiumStyle.green)
        }
        .padding(10)
        .background(PremiumStyle.softPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PremiumStyle.line, lineWidth: 1)
        }
    }
}

private struct ProgressMeter: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PremiumStyle.ink.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * CGFloat(max(0, min(1, progress)))))
            }
        }
        .frame(height: 7)
    }
}

private struct EmptyDetailCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PremiumStyle.secondaryInk)
            Text(title)
                .font(PremiumStyle.titleFont)
                .foregroundStyle(PremiumStyle.ink)
            Text(message)
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
    }
}

private struct HistorySection: View {
    let sessions: [BatterySession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History")
                    .font(PremiumStyle.titleFont)
                    .foregroundStyle(PremiumStyle.ink)
                Spacer()
                Text("\(max(0, sessions.count)) sessions")
                    .font(PremiumStyle.smallFont)
                    .foregroundStyle(PremiumStyle.secondaryInk)
            }

            if sessions.isEmpty {
                EmptyHistory()
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions.prefix(12)) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: BatterySession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                Image(systemName: session.kind.systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.kind.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(PremiumStyle.ink)
                    if session.isActive {
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                }
                Text(BatteryFormatters.sessionWindow(session))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(PremiumStyle.secondaryInk)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.startPercentage)% -> \(session.endPercentage)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PremiumStyle.ink)
                Text(BatteryFormatters.duration(session.duration))
                    .font(PremiumStyle.smallFont)
                    .foregroundStyle(PremiumStyle.secondaryInk)
            }
        }
        .padding(10)
        .background(PremiumStyle.softPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PremiumStyle.line, lineWidth: 1)
        }
    }

    private var tint: Color {
        session.kind == .charge ? PremiumStyle.green : PremiumStyle.graphite
    }
}

private struct MiniStatusPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk)
            Spacer(minLength: 8)
            Text(value)
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(PremiumStyle.softPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EmptyHistory: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(PremiumStyle.secondaryInk)
            Text("History starts as soon as power state changes.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(PremiumStyle.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(PremiumStyle.softPanel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PremiumStyle.line, lineWidth: 1)
        }
    }
}

private struct UnavailableCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "batteryblock")
                .font(.system(size: 24, weight: .semibold))
            Text("Battery data is unavailable")
                .font(PremiumStyle.titleFont)
            Text("This app needs a MacBook battery to record sessions.")
                .font(PremiumStyle.smallFont)
                .foregroundStyle(PremiumStyle.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
    }
}

private struct CycleInsights {
    static let planningLimit = 1000

    let count: Int?
    let remaining: Int?
    let loggedEquivalentCycles: Double
    let deepDrainCount: Int
    let cycleEvents: Int
    let lastCycleEvent: Date?
    let monthlyPace: Double?
    let projectedLimitDate: Date?

    init(snapshot: BatterySnapshot?, sessions: [BatterySession]) {
        count = snapshot?.cycleCount
        remaining = snapshot?.cycleCount.map { max(0, Self.planningLimit - $0) }
        loggedEquivalentCycles = sessions
            .filter { $0.kind == .discharge }
            .reduce(0) { total, session in
                total + Double(max(0, session.startPercentage - session.endPercentage)) / 100.0
            }
        deepDrainCount = sessions.filter { session in
            session.kind == .discharge && session.startPercentage - session.endPercentage >= 35
        }.count

        let changedSessions = sessions.filter { session in
            guard let start = session.startCycleCount, let end = session.endCycleCount else { return false }
            return end > start
        }
        cycleEvents = changedSessions.reduce(0) { total, session in
            guard let start = session.startCycleCount, let end = session.endCycleCount else { return total }
            return total + max(0, end - start)
        }
        lastCycleEvent = changedSessions.map(\.displayEndDate).max()

        var readings = sessions.flatMap { session -> [CycleReading] in
            var values: [CycleReading] = []
            if let start = session.startCycleCount {
                values.append(CycleReading(date: session.startDate, count: start))
            }
            if let end = session.endCycleCount {
                values.append(CycleReading(date: session.displayEndDate, count: end))
            }
            return values
        }
        if let snapshot, let count = snapshot.cycleCount {
            readings.append(CycleReading(date: snapshot.updatedAt, count: count))
        }
        readings.sort { $0.date < $1.date }

        if let first = readings.first, let last = readings.last {
            let cycleDelta = max(0, last.count - first.count)
            let days = last.date.timeIntervalSince(first.date) / 86_400
            if cycleDelta > 0, days >= 1 {
                let pace = Double(cycleDelta) / days * 30
                monthlyPace = pace
                if let remaining, remaining > 0, pace > 0.05 {
                    projectedLimitDate = Date().addingTimeInterval(Double(remaining) / pace * 30 * 86_400)
                } else {
                    projectedLimitDate = nil
                }
            } else {
                monthlyPace = nil
                projectedLimitDate = nil
            }
        } else {
            monthlyPace = nil
            projectedLimitDate = nil
        }
    }

    var limitProgress: Double {
        guard let count else { return 0 }
        return Double(count) / Double(Self.planningLimit)
    }

    var tint: Color {
        switch limitProgress {
        case 0..<0.65:
            return PremiumStyle.green
        case 0.65..<0.85:
            return PremiumStyle.amber
        default:
            return PremiumStyle.red
        }
    }

    var pressureLabel: String {
        switch limitProgress {
        case 0..<0.65:
            return "Low"
        case 0.65..<0.85:
            return "Watch"
        default:
            return "High"
        }
    }

    var remainingText: String {
        remaining.map(String.init) ?? "--"
    }

    var loggedEquivalentText: String {
        String(format: "%.1f", loggedEquivalentCycles)
    }

    var monthlyPaceText: String {
        guard let monthlyPace else { return "Learning" }
        return String(format: "%.1f", monthlyPace)
    }

    var lastCycleEventText: String {
        guard let lastCycleEvent else { return "None yet" }
        return BatteryFormatters.day.string(from: lastCycleEvent)
    }

    var projectedLimitText: String {
        guard let projectedLimitDate else { return "Learning" }
        return BatteryFormatters.monthYear.string(from: projectedLimitDate)
    }

    var velocityLabel: String {
        guard let monthlyPace else { return "Learning" }
        if monthlyPace < 3 { return "Low" }
        if monthlyPace < 8 { return "Normal" }
        return "Elevated"
    }

    var velocityDetail: String {
        guard let monthlyPace else { return "Needs more cycle history" }
        return "\(String(format: "%.1f", monthlyPace)) cycles per 30 days from stored readings"
    }

    var drainProfileLabel: String {
        if deepDrainCount == 0 { return "Shallow" }
        if deepDrainCount < 4 { return "Mixed" }
        return "Deep"
    }

    var drainProfileDetail: String {
        if deepDrainCount == 0 { return "No 35%+ discharge sessions recorded" }
        return "\(deepDrainCount) long discharge sessions recorded"
    }

    private struct CycleReading {
        let date: Date
        let count: Int
    }
}

private struct HealthInsights {
    let snapshot: BatterySnapshot?
    let samples: [BatteryHealthSample]

    var healthText: String {
        snapshot?.healthPercent.map { "\($0)%" } ?? "--"
    }

    var healthLabel: String {
        snapshot?.healthLabel ?? "Unknown"
    }

    var healthProgress: Double {
        Double(snapshot?.healthPercent ?? 0) / 100.0
    }

    var tint: Color {
        guard let health = snapshot?.healthPercent else { return PremiumStyle.graphite }
        switch health {
        case 90...:
            return PremiumStyle.green
        case 80..<90:
            return PremiumStyle.amber
        default:
            return PremiumStyle.red
        }
    }

    var driftTint: Color {
        guard let drift = healthDrift else { return PremiumStyle.graphite }
        return drift >= 0 ? PremiumStyle.green : PremiumStyle.amber
    }

    var maxCapacityText: String {
        capacityText(snapshot?.maxCapacity)
    }

    var designCapacityText: String {
        capacityText(snapshot?.designCapacity)
    }

    var capacityLostText: String {
        guard
            let designCapacity = snapshot?.designCapacity,
            let maxCapacity = snapshot?.maxCapacity,
            designCapacity > maxCapacity
        else {
            return "--"
        }
        return capacityText(designCapacity - maxCapacity)
    }

    var temperatureText: String {
        guard let temperature = snapshot?.temperatureCelsius else { return "--" }
        return "\(Int(temperature.rounded()))C"
    }

    var temperatureFootnote: String {
        guard let temperature = snapshot?.temperatureCelsius else { return "sensor" }
        if temperature < 35 { return "cool" }
        if temperature < 40 { return "warm" }
        return "hot"
    }

    var baselineText: String {
        guard let baseline = baselineHealth else { return "Starting now" }
        return "\(baseline)%"
    }

    var healthDriftText: String {
        guard let healthDrift else { return "Learning" }
        if healthDrift > 0 { return "+\(healthDrift)%" }
        return "\(healthDrift)%"
    }

    var healthDriftDetail: String {
        guard let baselineSample else { return "First baseline will be saved after refresh" }
        return "Since \(BatteryFormatters.day.string(from: baselineSample.date))"
    }

    var currentFillPercent: Int? {
        guard
            let currentCapacity = snapshot?.currentCapacity,
            let maxCapacity = snapshot?.maxCapacity,
            maxCapacity > 0
        else {
            return snapshot?.percentage
        }
        return max(0, min(100, Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())))
    }

    var headroomText: String {
        guard
            let currentCapacity = snapshot?.currentCapacity,
            let maxCapacity = snapshot?.maxCapacity,
            maxCapacity > currentCapacity
        else {
            return "--"
        }
        return capacityText(maxCapacity - currentCapacity)
    }

    private var baselineSample: BatteryHealthSample? {
        samples.reversed().first { $0.healthPercent != nil }
    }

    private var baselineHealth: Int? {
        baselineSample?.healthPercent
    }

    private var healthDrift: Int? {
        guard let baselineHealth, let current = snapshot?.healthPercent else { return nil }
        return current - baselineHealth
    }

    private func capacityText(_ value: Int?) -> String {
        guard let value else { return "--" }
        let ampHours = Double(value) / 1000.0
        return String(format: "%.1f Ah", ampHours)
    }
}

private struct BatteryOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let capWidth = rect.width * 0.07
        let body = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.12, width: rect.width - capWidth - 2, height: rect.height * 0.76)
        let cap = CGRect(x: body.maxX + 2, y: rect.midY - rect.height * 0.16, width: capWidth, height: rect.height * 0.32)

        path.addRoundedRect(in: body, cornerSize: CGSize(width: 8, height: 8))
        path.addRoundedRect(in: cap, cornerSize: CGSize(width: 3, height: 3))
        return path
    }
}

private struct BatteryFill: Shape {
    let level: Int

    func path(in rect: CGRect) -> Path {
        let capWidth = rect.width * 0.07
        let inset: CGFloat = 5
        let bodyWidth = rect.width - capWidth - 2
        let fillWidth = max(6, (bodyWidth - inset * 2) * CGFloat(max(0, min(100, level))) / 100)
        let fillRect = CGRect(
            x: rect.minX + inset,
            y: rect.minY + rect.height * 0.12 + inset,
            width: fillWidth,
            height: rect.height * 0.76 - inset * 2
        )

        var path = Path()
        path.addRoundedRect(in: fillRect, cornerSize: CGSize(width: 5, height: 5))
        return path
    }
}
