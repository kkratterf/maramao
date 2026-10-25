// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Maramao",
    // Italian is the source language of the UI; English comes from the String Catalog.
    defaultLocalization: "it",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Maramao", targets: ["Maramao"])
    ],
    dependencies: [
        // Auto-update (issue #28). The only third-party dependency: Sparkle is the
        // standard updater for macOS apps outside the App Store, and writing a safe
        // updater (signature checks, atomic replace, relaunch) by hand is not worth it.
        .package(url: "https://github.com/sparkle-project/Sparkle", .upToNextMajor(from: "2.9.0")),
    ],
    targets: [
        // Pure Pomodoro logic, no AppKit: unit-tested in CI.
        .target(name: "MaramaoCore", path: "Sources/MaramaoCore"),
        // The menu bar app and every break mode.
        .executableTarget(
            name: "Maramao",
            dependencies: [
                "MaramaoCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Maramao",
            // Italian keys, English translations (issue #30). build-app.sh copies the
            // compiled .lproj folders into Maramao.app, where SwiftUI and
            // String(localized:) look them up in Bundle.main.
            resources: [
                .process("Resources/Localizable.xcstrings"),
                // App Shortcut phrases: a .strings table, since AppShortcuts.xcstrings
                // needs macOS 14 and Maramao supports macOS 13.
                .process("Resources/en.lproj/AppShortcuts.strings"),
                .process("Resources/it.lproj/AppShortcuts.strings"),
            ]
        ),
        .testTarget(
            name: "MaramaoCoreTests",
            dependencies: ["MaramaoCore"],
            path: "Tests/MaramaoCoreTests"
        ),
    ]
)
