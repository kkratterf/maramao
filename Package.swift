// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Maramao",
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
            path: "Sources/Maramao"
        ),
        .testTarget(
            name: "MaramaoCoreTests",
            dependencies: ["MaramaoCore"],
            path: "Tests/MaramaoCoreTests"
        ),
    ]
)
