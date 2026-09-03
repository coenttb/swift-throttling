// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-throttling",
    platforms: [
        .macOS("27"),
        .iOS("27"),
        .tvOS("27"),
        .watchOS("27"),
        .visionOS("27")
    ],
    products: [
        .library(name: "Throttling", targets: ["Throttling"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Throttling",
            dependencies: []
        ),
        .testTarget(
            name: "Throttling Tests",
            dependencies: [
                .target(name: "Throttling")
            ]
        )
    ]
)

