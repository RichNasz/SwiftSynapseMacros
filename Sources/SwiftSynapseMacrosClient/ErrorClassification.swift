// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - API Error Categories

/// Semantic classification of API errors for structured handling.
public enum APIErrorCategory: Sendable {
    /// Authentication failure (401, invalid API key).
    case auth
    /// Quota or billing limit exceeded (402, 403).
    case quota
    /// Rate limited by the API (429, 529). Includes optional retry-after duration.
    case rateLimit(retryAfterSeconds: Int?)
    /// Network connectivity issue (DNS, timeout, connection reset).
    case connectivity
    /// Server-side error (500, 502, 503).
    case serverError
    /// Client error in the request (400, 422).
    case badRequest
    /// Unclassifiable error.
    case unknown
}

// MARK: - Tool Error Categories

/// Semantic classification of tool execution errors.
public enum ToolErrorCategory: Sendable {
    /// Failed to decode tool input from JSON.
    case inputDecoding
    /// Tool execution threw an error.
    case executionFailure
    /// Tool execution exceeded its timeout.
    case timeout
    /// Permission was denied for the tool.
    case permissionDenied
    /// Unclassifiable tool error.
    case unknown
}

// MARK: - Classified Error

/// An error enriched with semantic classification and execution context.
public struct ClassifiedError: Error, Sendable {
    /// The original error.
    public let underlyingError: Error
    /// The semantic category.
    public let category: APIErrorCategory
    /// The model that was being called (if applicable).
    public let model: String?
    /// Whether this error is safe to retry.
    public let isRetryable: Bool
    /// Suggested seconds to wait before retrying (from Retry-After header or similar).
    public let retryAfterSeconds: Int?

    public init(
        underlyingError: Error,
        category: APIErrorCategory,
        model: String? = nil,
        isRetryable: Bool = false,
        retryAfterSeconds: Int? = nil
    ) {
        self.underlyingError = underlyingError
        self.category = category
        self.model = model
        self.isRetryable = isRetryable
        self.retryAfterSeconds = retryAfterSeconds
    }
}

// MARK: - Classification Functions

/// Classifies an API error into a semantic category.
///
/// Inspects the error description and common HTTP status patterns to determine
/// the category. Use this for structured error handling, telemetry, and
/// rate-limit-aware retry logic.
public func classifyAPIError(_ error: Error, model: String? = nil) -> ClassifiedError {
    let description = String(describing: error).lowercased()

    // Authentication errors
    if description.contains("401") || description.contains("unauthorized")
        || description.contains("invalid api key") || description.contains("invalid_api_key")
        || description.contains("authentication") {
        return ClassifiedError(
            underlyingError: error, category: .auth, model: model, isRetryable: false
        )
    }

    // Quota / billing errors
    if description.contains("402") || description.contains("403")
        || description.contains("quota") || description.contains("billing")
        || description.contains("insufficient_quota") || description.contains("payment") {
        return ClassifiedError(
            underlyingError: error, category: .quota, model: model, isRetryable: false
        )
    }

    // Rate limiting
    if description.contains("429") || description.contains("529")
        || description.contains("rate_limit") || description.contains("rate limit")
        || description.contains("too many requests") || description.contains("overloaded") {
        let retryAfter = extractRetryAfter(from: description)
        return ClassifiedError(
            underlyingError: error, category: .rateLimit(retryAfterSeconds: retryAfter),
            model: model, isRetryable: true, retryAfterSeconds: retryAfter
        )
    }

    // Connectivity errors
    if description.contains("econnreset") || description.contains("econnrefused")
        || description.contains("epipe") || description.contains("etimedout")
        || description.contains("dns") || description.contains("network")
        || description.contains("connection") || description.contains("timed out")
        || description.contains("unreachable") || description.contains("nsurlerror") {
        return ClassifiedError(
            underlyingError: error, category: .connectivity, model: model, isRetryable: true
        )
    }

    // Server errors
    if description.contains("500") || description.contains("502")
        || description.contains("503") || description.contains("internal server error")
        || description.contains("bad gateway") || description.contains("service unavailable") {
        return ClassifiedError(
            underlyingError: error, category: .serverError, model: model, isRetryable: true
        )
    }

    // Bad request
    if description.contains("400") || description.contains("422")
        || description.contains("bad request") || description.contains("invalid_request")
        || description.contains("validation") {
        return ClassifiedError(
            underlyingError: error, category: .badRequest, model: model, isRetryable: false
        )
    }

    return ClassifiedError(
        underlyingError: error, category: .unknown, model: model, isRetryable: false
    )
}

/// Classifies a tool execution error into a semantic category.
public func classifyToolError(_ error: Error, toolName: String) -> ToolErrorCategory {
    let description = String(describing: error).lowercased()

    if description.contains("decoding") || description.contains("json")
        || description.contains("codable") || description.contains("parsing") {
        return .inputDecoding
    }

    if description.contains("timeout") || description.contains("timed out")
        || description.contains("deadline") {
        return .timeout
    }

    if description.contains("permission") || description.contains("denied")
        || description.contains("rejected") || description.contains("approval") {
        return .permissionDenied
    }

    if error is CancellationError {
        return .timeout
    }

    return .executionFailure
}

// MARK: - Helpers

private func extractRetryAfter(from description: String) -> Int? {
    // Try to find a retry-after value in the error description
    let patterns = ["retry-after: ", "retry_after: ", "retry after ", "retryafter="]
    for pattern in patterns {
        if let range = description.range(of: pattern) {
            let afterPattern = description[range.upperBound...]
            let digits = afterPattern.prefix(while: { $0.isNumber })
            if let seconds = Int(digits), seconds > 0 {
                return seconds
            }
        }
    }
    return nil
}
