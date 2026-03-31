// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TilePilot",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.1"),
    ],
    targets: [
        .executableTarget(
            name: "TilePilot",
            dependencies: ["TOMLKit", "HotKey"],
            path: "Sources/TilePilot",
            resources: [
                .copy("Resources/DefaultConfig.toml")
            ],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .testTarget(
            name: "TilePilotTests",
            dependencies: ["TilePilot"],
            path: "Tests/TilePilotTests"
        ),
    ]
)
