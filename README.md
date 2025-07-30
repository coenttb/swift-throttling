# swift-ratelimiter

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20tvOS%20|%20watchOS%20|%20Linux-lightgray.svg" alt="Platforms">
  <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Release-0.0.1-green.svg" alt="Release">
</p>

<p align="center">
  <strong>A powerful, actor-based rate limiter for Swift</strong><br>
  Multi-window rate limiting with exponential backoff, metrics, and enterprise-grade security
</p>

## Overview

**swift-ratelimiter** provides a generic, thread-safe rate limiting solution built with Swift's actor model. It supports multiple time windows, exponential backoff for failed attempts, comprehensive metrics collection, and follows security-first principles used by major platforms like GitHub, AWS, and Stripe.

```swift
import RateLimiter

// Create a rate limiter: 5 attempts per minute, 100 per hour
let rateLimiter = RateLimiter<String>(
    windows: [
        .minutes(1, maxAttempts: 5),
        .hours(1, maxAttempts: 100)
    ]
)

// Check rate limit for a user
let result = await rateLimiter.checkLimit("user123")
if result.isAllowed {
    // Process the request
    print("Request allowed. Remaining: \(result.remainingAttempts)")
} else {
    // Rate limited - respect the backoff
    print("Rate limited. Try again at: \(result.nextAllowedAttempt)")
    print("Backoff period: \(result.backoffInterval ?? 0) seconds")
}
```

## Why swift-ratelimiter?

### 🔒 Security First
- **Immediate backoff**: Any consecutive failure triggers exponential penalties
- **Attack prevention**: Stops brute force and credential stuffing attacks
- **Industry standard**: Follows patterns used by GitHub, AWS, and Stripe
- **Progressive penalties**: Each failure increases the backoff duration

### ⚡ High Performance
- **Actor-based**: Thread-safe without locks or queues
- **Memory efficient**: Bounded cache with LRU eviction
- **O(1) operations**: Fast lookups and updates
- **Concurrent ready**: Handles thousands of simultaneous requests

### 🎯 Flexible Design
- **Multiple windows**: Layer different time periods (5/min AND 100/hour)
- **Generic keys**: Works with any `Hashable & Sendable` type
- **Configurable backoff**: Customize exponential backoff behavior  
- **Metrics support**: Built-in monitoring and analytics hooks

### 🧩 Developer Friendly
- **Type-safe**: Full generic support with strict typing
- **Async/await**: Modern Swift concurrency patterns
- **Comprehensive tests**: 16 test scenarios covering edge cases

## Quick Start

### Installation

Add swift-ratelimiter to your Swift package:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-ratelimiter", from: "0.0.1")
]
```

For Xcode projects, add the package URL: `https://github.com/coenttb/swift-ratelimiter`

### Your First Rate Limiter

```swift
import RateLimiter

// Create a simple rate limiter
let loginLimiter = RateLimiter<String>(
    windows: [.minutes(15, maxAttempts: 5)] // 5 login attempts per 15 minutes
)

// In your authentication flow
func handleLogin(username: String, password: String) async -> LoginResult {
    let result = await loginLimiter.checkLimit(username)
    
    guard result.isAllowed else {
        return .rateLimited(
            nextAttempt: result.nextAllowedAttempt,
            backoffTime: result.backoffInterval
        )
    }
    
    // Attempt authentication
    let authResult = await authenticateUser(username, password)
    
    if authResult.success {
        await loginLimiter.recordSuccess(username)
        return .success(authResult.token)
    } else {
        await loginLimiter.recordFailure(username) // Triggers backoff
        return .invalidCredentials
    }
}
```

## Core Concepts

### 🏗️ Multiple Time Windows

Layer different rate limits for comprehensive protection:

```swift
let apiLimiter = RateLimiter<String>(
    windows: [
        .minutes(1, maxAttempts: 60),    // Burst protection
        .hours(1, maxAttempts: 1000),    // Hourly limit
        .hours(24, maxAttempts: 10000)   // Daily limit
    ]
)

// All windows must be satisfied - the most restrictive applies
let result = await apiLimiter.checkLimit("api-key-123")
```

### 🔥 Exponential Backoff

Failed attempts trigger increasing penalties:

```swift
let securityLimiter = RateLimiter<String>(
    windows: [.minutes(15, maxAttempts: 3)],
    backoffMultiplier: 2.0 // 2x, 4x, 8x, 16x...
)

// After consecutive failures:
// 1st failure: 30 minute backoff (2^1 * 15 min)
// 2nd failure: 60 minute backoff (2^2 * 15 min)  
// 3rd failure: 120 minute backoff (2^3 * 15 min)
```

### 📊 Metrics and Monitoring

Track usage patterns and abuse attempts:

```swift
let monitoredLimiter = RateLimiter<String>(
    windows: [.minutes(1, maxAttempts: 10)],
    metricsCallback: { key, result in
        // Log to your monitoring system
        logger.info("Rate limit check", metadata: [
            "key": .string(key),
            "allowed": .string(String(result.isAllowed)),
            "current_attempts": .string(String(result.currentAttempts)),
            "backoff_time": .string(String(result.backoffInterval ?? 0))
        ])
        
        // Send to analytics
        await analytics.track(.rateLimitCheck, properties: [
            "user_id": key,
            "status": result.isAllowed ? "allowed" : "blocked",
            "remaining": result.remainingAttempts
        ])
    }
)
```

## Real-World Examples

### 🔐 API Authentication

```swift
import RateLimiter

struct APIRateLimiter {
    private let keyLimiter: RateLimiter<String>
    private let ipLimiter: RateLimiter<String>
    
    init() {
        // API key limits: generous for authenticated users
        keyLimiter = RateLimiter(
            windows: [
                .minutes(1, maxAttempts: 100),
                .hours(1, maxAttempts: 5000)
            ]
        )
        
        // IP limits: strict for unauthenticated traffic
        ipLimiter = RateLimiter(
            windows: [
                .minutes(1, maxAttempts: 20),
                .hours(1, maxAttempts: 1000)
            ],
            backoffMultiplier: 3.0 // Aggressive backoff for suspicious IPs
        )
    }
    
    func checkLimits(apiKey: String?, clientIP: String) async -> RateLimitResult {
        // Always check IP limits
        let ipResult = await ipLimiter.checkLimit(clientIP)
        guard ipResult.isAllowed else { return ipResult }
        
        // Check API key limits if authenticated
        if let key = apiKey {
            return await keyLimiter.checkLimit(key)
        }
        
        return ipResult
    }
}
```

### 🔒 Login Protection

```swift
struct LoginRateLimiter {
    private let userLimiter: RateLimiter<String>
    private let ipLimiter: RateLimiter<String>
    
    init() {
        // Per-user limits: prevent credential stuffing
        userLimiter = RateLimiter(
            windows: [.minutes(15, maxAttempts: 5)],
            backoffMultiplier: 2.0,
            metricsCallback: self.logSecurityEvent
        )
        
        // Per-IP limits: prevent distributed attacks
        ipLimiter = RateLimiter(
            windows: [
                .minutes(1, maxAttempts: 10),
                .hours(1, maxAttempts: 100)
            ]
        )
    }
    
    func attemptLogin(username: String, clientIP: String) async -> Bool {
        // Check both user and IP limits
        let userResult = await userLimiter.checkLimit(username)
        let ipResult = await ipLimiter.checkLimit(clientIP)
        
        return userResult.isAllowed && ipResult.isAllowed
    }
    
    func recordLoginResult(username: String, success: Bool) async {
        if success {
            await userLimiter.recordSuccess(username)
        } else {
            await userLimiter.recordFailure(username)
        }
    }
    
    private func logSecurityEvent(_ key: String, _ result: RateLimitResult) async {
        if !result.isAllowed {
            logger.warning("Login rate limit exceeded", metadata: [
                "username": .string(key),
                "backoff_seconds": .string(String(result.backoffInterval ?? 0))
            ])
        }
    }
}
```

### 🌐 Web Server Middleware

```swift
import Vapor

func rateLimitMiddleware() -> Middleware {
    let limiter = RateLimiter<String>(
        windows: [
            .minutes(1, maxAttempts: 60),
            .hours(1, maxAttempts: 1000)
        ]
    )
    
    return { req, next in
        let clientIP = req.remoteAddress?.description ?? "unknown"
        let result = await limiter.checkLimit(clientIP)
        
        guard result.isAllowed else {
            throw Abort(.tooManyRequests, headers: [
                "Retry-After": String(Int(result.backoffInterval ?? 60)),
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": String(Int(result.nextAllowedAttempt?.timeIntervalSince1970 ?? 0))
            ])
        }
        
        let response = try await next.respond(to: req)
        
        // Add rate limit headers
        response.headers.add(name: "X-RateLimit-Remaining", value: String(result.remainingAttempts))
        response.headers.add(name: "X-RateLimit-Limit", value: "60")
        
        return response
    }
}
```

### 🔄 Retry Logic with Backoff

```swift
struct RetryableHTTPClient {
    private let retryLimiter = RateLimiter<String>(
        windows: [.minutes(1, maxAttempts: 3)],
        backoffMultiplier: 2.0
    )
    
    func performRequest(url: String) async throws -> Data {
        let result = await retryLimiter.checkLimit(url)
        
        guard result.isAllowed else {
            throw HTTPError.rateLimited(
                retryAfter: result.backoffInterval ?? 60
            )
        }
        
        do {
            let data = try await URLSession.shared.data(from: URL(string: url)!)
            await retryLimiter.recordSuccess(url)
            return data.0
        } catch {
            await retryLimiter.recordFailure(url)
            throw error
        }
    }
}
```

## API Reference

### Initialization

```swift
init(
    windows: [WindowConfig],
    maxCacheSize: Int = 10000,
    backoffMultiplier: Double = 2.0,
    metricsCallback: ((Key, RateLimitResult) async -> Void)? = nil
)
```

**Parameters:**
- `windows`: Time window configurations (automatically sorted by duration)
- `maxCacheSize`: Maximum keys to track (LRU eviction when exceeded)
- `backoffMultiplier`: Exponential backoff factor (2.0 = double each failure)
- `metricsCallback`: Optional monitoring callback for each rate limit check

### Core Methods

```swift
// Check if request is allowed
func checkLimit(_ key: Key, timestamp: Date = Date()) async -> RateLimitResult

// Record successful operation (resets consecutive failures)
func recordSuccess(_ key: Key) async

// Record failed operation (increases consecutive failures)
func recordFailure(_ key: Key) async

// Reset all data for a specific key
func reset(_ key: Key) async
```

### Window Configuration

```swift
struct WindowConfig {
    static func minutes(_ minutes: Int, maxAttempts: Int) -> WindowConfig
    static func hours(_ hours: Int, maxAttempts: Int) -> WindowConfig
}

// Custom durations
WindowConfig(duration: TimeInterval, maxAttempts: Int)
```

### Rate Limit Result

```swift
struct RateLimitResult {
    let isAllowed: Bool                    // Whether request should be allowed  
    let currentAttempts: Int              // Current attempts in window
    let remainingAttempts: Int            // Remaining attempts before limit
    let nextAllowedAttempt: Date?         // When next attempt is allowed
    let backoffInterval: TimeInterval?    // Current backoff duration in seconds
}
```

## Advanced Usage

### Custom Key Types

```swift
struct UserContext: Hashable, Sendable {
    let userId: String
    let endpoint: String
    let tier: UserTier
}

let contextLimiter = RateLimiter<UserContext>(
    windows: [.minutes(1, maxAttempts: 10)]
)

// Different limits per user tier, endpoint combination
let context = UserContext(userId: "123", endpoint: "/api/data", tier: .premium)
let result = await contextLimiter.checkLimit(context)
```

### Memory Management

```swift
// Configure cache size for high-traffic scenarios
let highVolumeLimiter = RateLimiter<String>(
    windows: [.minutes(1, maxAttempts: 100)],
    maxCacheSize: 50000 // Track up to 50k unique keys
)

// Least recently used keys are automatically evicted when cache is full
```

## Requirements

- Swift 5.10 (Full Swift 6 support)

## Dependencies

- [swift-bounded-cache](https://github.com/coenttb/swift-bounded-cache): Memory-efficient LRU cache

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## Support

- 🐛 **[Issue Tracker](https://github.com/coenttb/swift-ratelimiter/issues)** - Report bugs or request features
- 💬 **[Discussions](https://github.com/coenttb/swift-ratelimiter/discussions)** - Ask questions and share ideas
- 📧 **[Newsletter](http://coenttb.com/en/newsletter/subscribe)** - Stay updated
- 🐦 **[X (Twitter)](http://x.com/coenttb)** - Follow for updates
- 💼 **[LinkedIn](https://www.linkedin.com/in/tenthijeboonkkamp)** - Connect professionally

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://coenttb.com">coenttb</a><br>
</p>
