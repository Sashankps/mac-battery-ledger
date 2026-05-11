import Foundation

struct BatterySnapshot: Equatable {
    let percentage: Int
    let isPluggedIn: Bool
    let isCharging: Bool
    let isFullyCharged: Bool
    let timeRemainingMinutes: Int?
    let cycleCount: Int?
    let designCapacity: Int?
    let maxCapacity: Int?
    let currentCapacity: Int?
    let temperatureCelsius: Double?
    let updatedAt: Date

    var healthPercent: Int? {
        guard let designCapacity, let maxCapacity, designCapacity > 0 else { return nil }
        return Int((Double(maxCapacity) / Double(designCapacity) * 100).rounded())
    }

    var healthLabel: String {
        guard let healthPercent else { return "Unknown" }
        switch healthPercent {
        case 90...:
            return "Excellent"
        case 80..<90:
            return "Good"
        case 70..<80:
            return "Fair"
        default:
            return "Service Soon"
        }
    }

    var powerStateLabel: String {
        if isFullyCharged { return "Fully Charged" }
        if isCharging { return "Charging" }
        if isPluggedIn { return "Connected" }
        return "On Battery"
    }

    var batterySymbolName: String {
        if isCharging || isPluggedIn {
            return "battery.100percent.bolt"
        }

        switch percentage {
        case 91...100:
            return "battery.100percent"
        case 66...90:
            return "battery.75percent"
        case 36...65:
            return "battery.50percent"
        case 11...35:
            return "battery.25percent"
        default:
            return "battery.0percent"
        }
    }
}

enum BatterySessionKind: String, Codable, CaseIterable {
    case charge
    case discharge

    var title: String {
        switch self {
        case .charge:
            return "Charge"
        case .discharge:
            return "Discharge"
        }
    }

    var systemImage: String {
        switch self {
        case .charge:
            return "bolt.fill"
        case .discharge:
            return "arrow.down.right"
        }
    }
}

struct BatterySession: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: BatterySessionKind
    var startDate: Date
    var endDate: Date?
    var startPercentage: Int
    var endPercentage: Int
    var startCycleCount: Int?
    var endCycleCount: Int?

    var isActive: Bool {
        endDate == nil
    }

    var displayEndDate: Date {
        endDate ?? Date()
    }

    var duration: TimeInterval {
        displayEndDate.timeIntervalSince(startDate)
    }

    var percentageDelta: Int {
        endPercentage - startPercentage
    }
}

struct BatteryHistory: Codable, Equatable {
    var activeSession: BatterySession?
    var sessions: [BatterySession]

    static let empty = BatteryHistory(activeSession: nil, sessions: [])
}
