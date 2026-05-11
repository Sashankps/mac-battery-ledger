import SwiftUI

struct BatteryPanel: View {
    @Bindable var monitor: BatteryMonitor

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

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let snapshot {
                        HeroBatteryCard(snapshot: snapshot)
                        MetricGrid(snapshot: snapshot)
                    } else {
                        UnavailableCard()
                    }

                    HistorySection(sessions: visibleSessions)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

            footer
        }
        .background(PremiumStyle.panel)
        .task {
            monitor.start()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("mac-battery-ledger")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PremiumStyle.ink)
                Text(snapshot?.powerStateLabel ?? "Reading Battery")
                    .font(PremiumStyle.smallFont)
                    .foregroundStyle(PremiumStyle.secondaryInk)
            }

            Spacer()

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

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
                .help("Quit mac-battery-ledger")
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
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

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            MetricTile(title: "Cycles", value: snapshot.cycleCount.map(String.init) ?? "—", footnote: "count")
            MetricTile(title: "Health", value: snapshot.healthPercent.map { "\($0)%" } ?? "—", footnote: snapshot.healthLabel)
            MetricTile(title: "Capacity", value: capacityText, footnote: "of design")
        }
    }

    private var capacityText: String {
        guard let maxCapacity = snapshot.maxCapacity, let designCapacity = snapshot.designCapacity, designCapacity > 0 else {
            return "—"
        }
        return "\(Int((Double(maxCapacity) / Double(designCapacity) * 100).rounded()))%"
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
