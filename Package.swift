// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "mac-battery-ledger",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "mac-battery-ledger", targets: ["MacBatteryLedgerApp"])
    ],
    targets: [
        .executableTarget(
            name: "MacBatteryLedgerApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
