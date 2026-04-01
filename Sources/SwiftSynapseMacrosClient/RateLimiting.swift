// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Rate Limit Policy

/// Configuration for rate-limit-aware retry behavior.
public struct RateLimitPolicy: Sendable {
    /// Maximum retry attempts specifically for rate limit errors (429/529).
    public let maxRetries: Int
    /// Initial backoff duration before first retry.
    public let initialBackoff: Duration
    /// Maximum backoff duration cap.
    public let maxBackoff: Duration
    /// Jitter factor (0.0–1.0) to randomize backoff and avoid thundering herd.
    public let jitterFactor: Double

    public init(
        maxRetries: Int = 5,
        initialBackoff: Duration = .milliseconds(1000),
        maxBackoff: Duration = .seconds(60),
        jitterFactor: Double = 0.25
    ) {
        self.maxRetries = maxRetries
        self.initialBackoff = initialBackoff
        self.maxBackoff = maxBackoff
        self.jitterFactor = jitterFactor
    }

    public static var `default`: RateLimitPolicy { RateLimitPolicy() }
}

// MARK: - Rate Limit Errors

/// Errors specific to rate limiting.
public enum RateLimitError: Error, Sendable {
    /// The API returned a 429 (rate limited). Includes optional suggested wait time.
    case rateLimited(retryAfter: Duration?)
    /// The API returned a 529 (server overloaded). Includes optional suggested wait time.
    case serverOverloaded(retryAfter: Duration?)
    /// Rate limit retries exhausted.
    case retriesExhausted(lastError: Error)
}

// MARK: - Rate Limit State

/// Tracks per-model cooldown state for rate-limit-aware retry logic.
///
/// When a rate limit is hit, the state enters a cooldown period. Subsequent
/// requests check the cooldown before sending, avoiding wasted API calls.
public actor RateLimitState {
    private var cooldownUntil: ContinuousClock.Instant?
    private var consecutiveRateLimits: Int = 0

    public init() {}

    /// Whether the state is currently in a cooldown period.
    public var isInCooldown: Bool {
        guard let until = cooldownUntil else { return false }
        return ContinuousClock.now < until
    }

    /// The remaining cooldown duration, or nil if not in cooldown.
    public var remainingCooldown: Duration? {
        guard let until = cooldownUntil else { return nil }
        let remaining = until - ContinuousClock.now
        return remaining > .zero ? remaining : nil
    }

    /// Number of consecutive rate limit hits (resets on success).
    public var consecutiveHits: Int { consecutiveRateLimits }

    /// Enters a cooldown period for the given duration.
    public func enterCooldown(duration: Duration) {
        cooldownUntil = ContinuousClock.now + duration
        consecutiveRateLimits += 1
    }

    /// Records a successful request, resetting the consecutive counter.
    public func recordSuccess() {
        consecutiveRateLimits = 0
        cooldownUntil = nil
    }

    /// Waits until the cooldown expires (if active).
    public func waitForCooldown() async {
        guard let until = cooldownUntil else { return }
        let remaining = until - ContinuousClock.now
        if remaining > .zero {
            try? await Task.sleep(for: remaining)
        }
    }
}

// MARK: - Rate-Limit-Aware Retry

/// Retries an async operation with rate-limit awareness.
///
/// Wraps `retryWithBackoff` but adds rate-limit-specific behavior:
/// - Checks cooldown before sending (avoids wasted calls)
/// - Parses `Retry-After` from error context
/// - Enters cooldown on rate limit errors
/// - Uses jittered exponential backoff
///
/// ```swift
/// let state = RateLimitState()
/// let response = try await retryWithRateLimit(
///     rateLimitState: state,
///     policy: .default
/// ) {
///     try await client.send(request)
/// }
/// ```
public func retryWithRateLimit<T: Sendable>(
    rateLimitState: RateLimitState,
    policy: RateLimitPolicy = .default,
    telemetry: (any TelemetrySink)? = nil,
    operation: @Sendable () async throws -> T
) async throws -> T {
    // Wait for any existing cooldown before starting
    await rateLimitState.waitForCooldown()

    var lastError: Error?
    var currentBackoff = policy.initialBackoff

    for attempt in 0..<policy.maxRetries {
        do {
            let result = try await operation()
            await rateLimitState.recordSuccess()
            return result
        } catch {
            lastError = error

            let classified = classifyAPIError(error)
            switch classified.category {
            case .rateLimit(let retryAfter):
                // Enter cooldown based on retry-after or calculated backoff
                let cooldownDuration: Duration
                if let retryAfter, retryAfter > 0 {
                    cooldownDuration = .seconds(retryAfter)
                } else {
                    cooldownDuration = applyJitter(currentBackoff, factor: policy.jitterFactor)
                }
                await rateLimitState.enterCooldown(duration: cooldownDuration)

                telemetry?.emit(TelemetryEvent(kind: .retryAttempted(error: error, attempt: attempt + 1)))

                // Wait for the cooldown
                await rateLimitState.waitForCooldown()

                // Increase backoff for next attempt
                currentBackoff = min(currentBackoff * 2, policy.maxBackoff)

            default:
                // Non-rate-limit error — don't retry here, let the caller handle it
                throw error
            }
        }
    }

    throw RateLimitError.retriesExhausted(lastError: lastError!)
}

// MARK: - Helpers

private func applyJitter(_ duration: Duration, factor: Double) -> Duration {
    guard factor > 0 else { return duration }
    let jitter = Double.random(in: -factor...factor)
    let components = duration.components
    let totalNanos = Double(components.seconds) * 1_000_000_000 + Double(components.attoseconds) / 1_000_000_000
    let jitteredNanos = totalNanos * (1.0 + jitter)
    return Duration.nanoseconds(Int64(jitteredNanos))
}
