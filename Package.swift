// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AwayLock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AwayLock", targets: ["AwayLock"]),
        .library(name: "AwayLockCore", targets: ["AwayLockCore"])
    ],
    targets: [
        .executableTarget(
            name: "AwayLock",
            dependencies: ["AwayLockCore"]
        ),
        .target(
            name: "AwayLockCore",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "AwayLockTests",
            dependencies: ["AwayLockCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
