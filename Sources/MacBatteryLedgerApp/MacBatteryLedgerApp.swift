import AppKit
import SwiftUI

@main
struct MacBatteryLedgerApp: App {
    @State private var monitor = BatteryMonitor()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            BatteryPanel(monitor: monitor)
                .frame(width: 390)
                .onAppear {
                    monitor.refresh()
                }
        } label: {
            MenuBarBatteryLabel(snapshot: monitor.snapshot)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: NSApplication.shared.isActive) {
            monitor.refresh()
        }

        Settings {
            EmptyView()
        }
    }
}

private struct MenuBarBatteryLabel: View {
    let snapshot: BatterySnapshot?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: snapshot?.batterySymbolName ?? "battery.100percent")
                .symbolRenderingMode(.hierarchical)
            Text("\(snapshot?.percentage ?? 0)%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
        .task {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
