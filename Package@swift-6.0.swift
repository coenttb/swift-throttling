// swift-tools-version:6.0

import PackageDescription

extension String {
    static let rateLimiter: Self = "RateLimiter"
}

extension Target.Dependency {
    static var rateLimiter: Self { .target(name: .rateLimiter) }
    static var boundedCache: Self { .product(name: "BoundedCache", package: "swift-bounded-cache") }
}

let package = Package(
    name: "swift-ratelimiter",
    products: [
        .library(name: .rateLimiter, targets: [.rateLimiter])
    ],
    dependencies: [
        .package(url: "https://github.com/coenttb/swift-bounded-cache", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: .rateLimiter,
            dependencies: [
                .boundedCache
            ]
        ),
        .testTarget(
            name: .rateLimiter.tests,
            dependencies: [
                .rateLimiter
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

extension String { var tests: Self { self + " Tests" } }
