// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexTaskbar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexTaskbar", targets: ["CodexTaskbar"])
    ],
    targets: [
        .executableTarget(
            name: "CodexTaskbar",
            path: "Sources/CodexTaskbar"
        )
    ]
)
