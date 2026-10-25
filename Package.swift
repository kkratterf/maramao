// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Maramao",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Maramao", targets: ["Maramao"])
    ],
    targets: [
        // Pure Pomodoro logic, no AppKit: unit-tested in CI.
        .target(name: "MaramaoCore", path: "Sources/MaramaoCore"),
        // The menu bar app and every break mode.
        .executableTarget(
            name: "Maramao",
            dependencies: ["MaramaoCore"],
            path: "Sources/Maramao"
        ),
        .testTarget(
            name: "MaramaoCoreTests",
            dependencies: ["MaramaoCore"],
            path: "Tests/MaramaoCoreTests"
        ),
    ]
)
