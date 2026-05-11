import Foundation
import IOKit
import IOKit.ps

protocol BatteryReading {
    func readSnapshot() -> BatterySnapshot?
}

final class BatteryReader: BatteryReading {
    func readSnapshot() -> BatterySnapshot? {
        guard let powerSource = readPowerSourceDescription() else { return nil }
        let registry = readSmartBatteryRegistry()

        let percentage = intValue(powerSource[kIOPSCurrentCapacityKey])
            ?? intValue(registry["CurrentCapacity"])
            ?? 0
        let isCharging = boolValue(powerSource[kIOPSIsChargingKey])
            ?? boolValue(registry["IsCharging"])
            ?? false
        let isPluggedIn = boolValue(registry["ExternalConnected"])
            ?? (stringValue(powerSource[kIOPSPowerSourceStateKey]) == kIOPSACPowerValue)
        let isFullyCharged = (boolValue(powerSource[kIOPSIsChargedKey])
            ?? boolValue(registry["FullyCharged"]))
            ?? (percentage >= 100)
        let timeRemaining = intValue(powerSource[kIOPSTimeToEmptyKey])
            ?? intValue(powerSource[kIOPSTimeToFullChargeKey])
            ?? intValue(registry["TimeRemaining"])
        let safeTimeRemaining = timeRemaining.flatMap { $0 > 0 && $0 < 65_535 ? $0 : nil }

        return BatterySnapshot(
            percentage: max(0, min(100, percentage)),
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            isFullyCharged: isFullyCharged,
            timeRemainingMinutes: safeTimeRemaining,
            cycleCount: intValue(registry["CycleCount"]),
            maximumCapacityPercent: readSystemMaximumCapacityPercent(),
            designCapacity: intValue(registry["DesignCapacity"]),
            maxCapacity: intValue(registry["AppleRawMaxCapacity"])
                ?? intValue(registry["NominalChargeCapacity"]),
            currentCapacity: intValue(registry["AppleRawCurrentCapacity"]),
            temperatureCelsius: intValue(registry["Temperature"]).map { Double($0) / 100.0 },
            updatedAt: Date()
        )
    }

    private func readPowerSourceDescription() -> [String: Any]? {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
            let source = sources.first,
            let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
        else {
            return nil
        }

        return description
    }

    private func readSmartBatteryRegistry() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return [:] }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let dictionary = properties?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }

        return dictionary
    }

    private func readSystemMaximumCapacityPercent() -> Int? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("Maximum Capacity:") else { continue }
            let digits = trimmed.compactMap { $0.isNumber ? String($0) : nil }.joined()
            return Int(digits)
        }

        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as Int64:
            return Int(value)
        case let value as UInt64:
            return value <= UInt64(Int.max) ? Int(value) : nil
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let value as Bool:
            return value
        case let value as NSNumber:
            return value.boolValue
        case let value as String:
            return ["yes", "true", "1"].contains(value.lowercased())
        default:
            return nil
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            return value
        default:
            return nil
        }
    }
}
