import Foundation
import IOKit
import IOKit.ps

protocol BatteryReading {
    func readSnapshot() -> BatterySnapshot?
}

final class BatteryReader: BatteryReading {
    private static let maximumCapacityRefreshInterval: TimeInterval = 60 * 60

    private let metricsQueue = DispatchQueue(label: "com.sashi.mac-battery-ledger.system-metrics")
    private var cachedMaximumCapacityPercent: Int?
    private var maximumCapacityReadAt: Date?
    private var isRefreshingMaximumCapacity = false

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
        let powerTelemetry = dictionaryValue(registry["PowerTelemetryData"])
        let adapterDetails = dictionaryValue(registry["AdapterDetails"])
            ?? firstDictionaryValue(registry["AppleRawAdapterDetails"])
        let systemPowerInWatts = milliwattsValue(powerTelemetry?["SystemPowerIn"])
        let batteryTelemetryWatts = signedMilliwattsValue(powerTelemetry?["BatteryPower"])
        let batteryVoltage = millivoltsValue(registry["Voltage"])
            ?? millivoltsValue(registry["AppleRawBatteryVoltage"])
        let batteryCurrent = milliampsValue(registry["InstantAmperage"])
            ?? milliampsValue(registry["Amperage"])
        let batteryFlowWatts = powerWatts(volts: batteryVoltage, amps: batteryCurrent) ?? batteryTelemetryWatts
        let powerDraw = Self.powerDraw(
            isPluggedIn: isPluggedIn,
            systemPowerInWatts: systemPowerInWatts,
            batteryFlowWatts: batteryFlowWatts,
            batteryTelemetryWatts: batteryTelemetryWatts
        )

        return BatterySnapshot(
            percentage: max(0, min(100, percentage)),
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            isFullyCharged: isFullyCharged,
            timeRemainingMinutes: safeTimeRemaining,
            powerDrawWatts: powerDraw.watts,
            powerDrawSource: powerDraw.source,
            batteryFlowWatts: batteryFlowWatts,
            batteryVoltage: batteryVoltage,
            batteryCurrent: batteryCurrent,
            adapterName: stringValue(adapterDetails?["Name"])?.trimmingCharacters(in: .whitespacesAndNewlines),
            adapterManufacturer: stringValue(adapterDetails?["Manufacturer"]),
            adapterRatedWatts: intValue(adapterDetails?["Watts"]),
            adapterVoltage: millivoltsValue(adapterDetails?["AdapterVoltage"]),
            adapterCurrent: milliampsValue(adapterDetails?["Current"]),
            cycleCount: intValue(registry["CycleCount"]),
            maximumCapacityPercent: cachedSystemMaximumCapacityPercent(),
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

    private func cachedSystemMaximumCapacityPercent() -> Int? {
        var cachedValue: Int?
        var shouldRefresh = false
        let now = Date()

        metricsQueue.sync {
            cachedValue = cachedMaximumCapacityPercent
            let age = maximumCapacityReadAt.map { now.timeIntervalSince($0) } ?? .infinity
            shouldRefresh = !isRefreshingMaximumCapacity && age >= Self.maximumCapacityRefreshInterval
            if shouldRefresh {
                isRefreshingMaximumCapacity = true
            }
        }

        if shouldRefresh {
            metricsQueue.async { [weak self] in
                let nextValue = Self.readSystemMaximumCapacityPercent()
                self?.cachedMaximumCapacityPercent = nextValue
                self?.maximumCapacityReadAt = Date()
                self?.isRefreshingMaximumCapacity = false
            }
        }

        return cachedValue
    }

    private static func readSystemMaximumCapacityPercent() -> Int? {
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

    private static func powerDraw(
        isPluggedIn: Bool,
        systemPowerInWatts: Double?,
        batteryFlowWatts: Double?,
        batteryTelemetryWatts: Double?
    ) -> (watts: Double?, source: PowerDrawSource) {
        if isPluggedIn, let systemPowerInWatts, systemPowerInWatts > 0 {
            return (systemPowerInWatts, .adapterTelemetry)
        }

        if let batteryTelemetryWatts {
            return (abs(batteryTelemetryWatts), .batteryTelemetry)
        }

        if let batteryFlowWatts {
            return (abs(batteryFlowWatts), .batteryEstimate)
        }

        return (nil, .unavailable)
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

    private func signedIntValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as Int64:
            return Int(value)
        case let value as UInt64:
            return Int(Int64(bitPattern: value))
        case let value as NSNumber:
            let uint64 = value.uint64Value
            if uint64 > UInt64(Int64.max) {
                return Int(Int64(bitPattern: uint64))
            }
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private func milliwattsValue(_ value: Any?) -> Double? {
        intValue(value).map { Double($0) / 1000.0 }
    }

    private func signedMilliwattsValue(_ value: Any?) -> Double? {
        signedIntValue(value).map { Double($0) / 1000.0 }
    }

    private func millivoltsValue(_ value: Any?) -> Double? {
        intValue(value).map { Double($0) / 1000.0 }
    }

    private func milliampsValue(_ value: Any?) -> Double? {
        signedIntValue(value).map { Double($0) / 1000.0 }
    }

    private func powerWatts(volts: Double?, amps: Double?) -> Double? {
        guard let volts, let amps else { return nil }
        return volts * amps
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

    private func dictionaryValue(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private func firstDictionaryValue(_ value: Any?) -> [String: Any]? {
        if let dictionaries = value as? [[String: Any]] {
            return dictionaries.first
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? [String: Any] }.first
        }
        return nil
    }
}
