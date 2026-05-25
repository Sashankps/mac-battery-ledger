import AppKit
import ServiceManagement
import SwiftUI

@main
struct MacBatteryLedgerApp: App {
    @State private var monitor = BatteryMonitor()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        configureLaunchAtLogin()
    }

    var body: some Scene {
        MenuBarExtra {
            BatteryPanel(monitor: monitor)
                .frame(width: 390, height: 600)
        } label: {
            MenuBarBatteryLabel(snapshot: monitor.snapshot)
                .task {
                    monitor.start()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            EmptyView()
        }
    }

    private func configureLaunchAtLogin() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        guard SMAppService.mainApp.status != .enabled else { return }

        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("mac-battery-ledger: failed to register Login Item: \(error.localizedDescription)")
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
