# swift-throttling

[![CI](https://github.com/coenttb/swift-throttling/workflows/CI/badge.svg)](https://github.com/coenttb/swift-throttling/actions/workflows/ci.yml)
![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Actor-based rate limiting and request pacing for Swift.

## Overview

swift-throttling provides thread-safe rate limiting and request pacing built with Swift's actor model. It supports multiple time windows, exponential backoff for failed attempts, and comprehensive metrics collection.

## Features

- **RateLimiter**: Multi-window rate limiting with exponential backoff
- **RequestPacer**: Smooth request distribution to avoid burst traffic
- **ThrottledClient**: Combined rate limiting and pacing wrapper
- **Generic Keys**: Works with any `Hashable & Sendable` type
- **Metrics Support**: Built-in callbacks for monitoring and analytics
- **Memory Efficient**: Bounded cache with LRU eviction
- **Swift Concurrency**: Built with actors for thread-safe concurrent access

## Installation

Add swift-throttling to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-throttling", from: "0.0.1")
]
```

## Quick Start

### Basic Rate Limiting

```swift
import Throttling

// Create a rate limiter: 5 attempts per minute, 100 per hour
let rateLimiter = RateLimiter<String>(
    windows: [
        .minutes(1, maxAttempts: 5),
        .hours(1, maxAttempts: 100)
    ]
)

// Check rate limit
let result = await rateLimiter.checkLimit("user123")
if result.isAllowed {
    await rateLimiter.recordAttempt("user123")
    // Process request
} else {
    // Rate limited
    print("Retry after: \(result.nextAllowedAttempt)")
}
```

### Request Pacing

```swift
import Throttling

// Create a pacer for 10 requests per second
let pacer = RequestPacer<String>(targetRate: 10.0)

// Schedule a request
let result = await pacer.scheduleRequest("api-client")
if result.delay > 0 {
    try await Task.sleep(nanoseconds: UInt64(result.delay * 1_000_000_000))
}
// Make request
```

### Combined Throttling

```swift
import Throttling

// Combine rate limiting and pacing
let client = ThrottledClient<String>(
    windows: [.seconds(1, maxAttempts: 10)],
    targetRate: 5.0
)

let result = await client.acquire("user123")
if result.canProceed {
    try await result.waitUntilReady()
    // Make request

    // Record outcome
    if success {
        await client.recordSuccess("user123")
    } else {
        await client.recordFailure("user123")
    }
}
```

## Usage

### Multiple Time Windows

Layer different rate limits for comprehensive protection:

```swift
let apiLimiter = RateLimiter<String>(
    windows: [
        .minutes(1, maxAttempts: 60),    // Burst protection
        .hours(1, maxAttempts: 1000),    // Hourly limit
        .hours(24, maxAttempts: 10000)   // Daily limit
    ]
)
```

All windows must be satisfied. The most restrictive applies.

### Exponential Backoff

Failed attempts trigger increasing penalties:

```swift
let limiter = RateLimiter<String>(
    windows: [.minutes(15, maxAttempts: 3)],
    backoffMultiplier: 2.0
)

// After consecutive failures:
// 1st failure: 30 minute backoff (2^1 * 15 min)
// 2nd failure: 60 minute backoff (2^2 * 15 min)
// 3rd failure: 120 minute backoff (2^3 * 15 min)
```

### Metrics Collection

Track usage patterns:

```swift
let limiter = RateLimiter<String>(
    windows: [.minutes(1, maxAttempts: 10)],
    metricsCallback: { key, result in
        print("Key: \(key), Allowed: \(result.isAllowed)")
    }
)
```

### Custom Key Types

```swift
struct UserContext: Hashable, Sendable {
    let userId: String
    let endpoint: String
}

let limiter = RateLimiter<UserContext>(
    windows: [.minutes(1, maxAttempts: 10)]
)

let context = UserContext(userId: "123", endpoint: "/api/data")
let result = await limiter.checkLimit(context)
```

## API Reference

### RateLimiter

```swift
public actor RateLimiter<Key: Hashable & Sendable>

// Initialization
init(
    windows: [WindowConfig],
    maxCacheSize: Int = 10000,
    backoffMultiplier: Double = 2.0,
    metricsCallback: (@Sendable (Key, RateLimitResult) async -> Void)? = nil
)

// Check limit (read-only)
func checkLimit(_ key: Key, timestamp: Date = Date()) async -> RateLimitResult

// Record attempt (increments counter)
func recordAttempt(_ key: Key, timestamp: Date = Date()) async

// Record success (resets consecutive failures)
func recordSuccess(_ key: Key) async

// Record failure (increases consecutive failures)
func recordFailure(_ key: Key) async

// Reset all data for key
func reset(_ key: Key) async
```

### WindowConfig

```swift
struct WindowConfig: Sendable {
    static func seconds(_ seconds: Int, maxAttempts: Int) -> WindowConfig
    static func minutes(_ minutes: Int, maxAttempts: Int) -> WindowConfig
    static func hours(_ hours: Int, maxAttempts: Int) -> WindowConfig

    init(duration: TimeInterval, maxAttempts: Int)
}
```

### RateLimitResult

```swift
struct RateLimitResult: Sendable {
    let isAllowed: Bool
    let currentAttempts: Int
    let remainingAttempts: Int
    let nextAllowedAttempt: Date?
    let backoffInterval: TimeInterval?
}
```

### RequestPacer

```swift
public actor RequestPacer<Key: Hashable & Sendable>

init(
    targetRate: Double,
    rateLimiter: RateLimiter<Key>? = nil,
    allowCatchUp: Bool = false
)

func scheduleRequest(_ key: Key, timestamp: Date = Date()) async -> ScheduleResult
func reset(_ key: Key) async
```

### ThrottledClient

```swift
public struct ThrottledClient<Key: Hashable & Sendable>: Sendable

init(rateLimiter: RateLimiter<Key>? = nil, pacer: RequestPacer<Key>? = nil)
init(windows: [RateLimiter<Key>.WindowConfig], targetRate: Double, backoffMultiplier: Double = 2.0)

func acquire(_ key: Key, timestamp: Date = Date()) async -> AcquisitionResult
func recordSuccess(_ key: Key) async
func recordFailure(_ key: Key) async
func reset(_ key: Key) async
```

## Requirements

- Swift 6.0+
- Platforms: macOS, iOS, tvOS, watchOS, Linux, Windows

## Dependencies

- [swift-bounded-cache](https://github.com/coenttb/swift-bounded-cache): Memory-efficient LRU cache implementation

## Related Packages

- [swift-bounded-cache](https://github.com/coenttb/swift-bounded-cache): Memory-efficient LRU cache implementation

## Contributing

Contributions are welcome. Please open an issue to discuss significant changes before submitting a pull request.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
