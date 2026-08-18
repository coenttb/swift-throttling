// swift-tools-version: 6.3.3

import PackageDescription

extension String {
    static let throttling: Self = "Throttling"
}

extension Target.Dependency {
    static var throttling: Self { .target(name: .throttling) }
}

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
        .library(name: .throttling, targets: [.throttling])
    ],
    dependencies: [],
    targets: [
        .target(
            name: .throttling,
            dependencies: []
        ),
        .testTarget(
            name: .throttling.tests,
            dependencies: [
                .throttling
            ]
        )
    ]
)

extension String { var tests: Self { self + " Tests" } }
