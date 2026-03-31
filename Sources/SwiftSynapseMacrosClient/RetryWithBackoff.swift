// Generated from CodeGenSpecs/Shared-Retry-Strategy.md — Do not edit manually. Update spec and re-generate.

import Foundation

/// Default predicate for transport-level retryable errors.
///
/// Returns `true` for transient network conditions that may resolve on retry.
public func isTransportRetryable(_ error: Error) -> Bool {
    if let urlError = error as? URLError {
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
    return false
}

/// Retries an async operation with exponential backoff.
///
/// Only the operation closure is retried — callers should wrap only the
/// `LLMClient.send()` call, not the entire `execute()` body.
///
/// - Parameters:
///   - maxAttempts: Maximum number of attempts (1 = no retry). Default: 3.
///   - baseDelay: Initial delay before first retry. Doubles each attempt. Default: 500ms.
///   - isRetryable: Predicate classifying errors as retryable. Default: `isTransportRetryable`.
///   - onRetry: Callback fired before each retry sleep with the error and failed attempt number (1-indexed).
///   - operation: The async operation to attempt.
/// - Returns: The operation's result on success.
/// - Throws: The last error if all attempts fail, or a non-retryable error immediately.
public func retryWithBackoff<T: Sendable>(
    maxAttempts: Int = 3,
    baseDelay: Duration = .milliseconds(500),
    isRetryable: @Sendable (Error) -> Bool = SwiftSynapseMacrosClient.isTransportRetryable,
    onRetry: (@Sendable (Error, Int) -> Void)? = nil,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            guard isRetryable(error), attempt < maxAttempts else {
                throw error
            }
            onRetry?(error, attempt)
            let delay = baseDelay * Double(1 << (attempt - 1))
            try await Task.sleep(for: delay)
        }
    }
    throw lastError!
}
