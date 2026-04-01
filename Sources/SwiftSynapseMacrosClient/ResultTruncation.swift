// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Truncation Policy

/// Controls how oversized tool results are truncated before entering the transcript.
///
/// By default, the maximum is derived from `AgentConfiguration.toolResultBudgetTokens * 4`
/// (approximate chars-to-tokens ratio). Results under the limit pass through unchanged.
public struct TruncationPolicy: Sendable {
    /// Maximum characters allowed before truncation.
    public let maxCharacters: Int
    /// Number of characters to preserve from the end (most recent output is usually most relevant).
    public let preserveLastCharacters: Int

    public init(
        maxCharacters: Int = 16384,
        preserveLastCharacters: Int = 200
    ) {
        self.maxCharacters = maxCharacters
        self.preserveLastCharacters = preserveLastCharacters
    }

    /// Creates a policy from an `AgentConfiguration`'s tool result budget.
    public static func fromConfig(_ config: AgentConfiguration) -> TruncationPolicy {
        TruncationPolicy(maxCharacters: config.toolResultBudgetTokens * 4)
    }
}

// MARK: - Result Truncator

/// Truncates oversized tool results to prevent context window waste.
///
/// When a tool result exceeds the policy's `maxCharacters`, the truncator
/// preserves the last N characters (most relevant) and prepends a header
/// indicating the original size.
///
/// ```swift
/// let policy = TruncationPolicy(maxCharacters: 8192)
/// let truncated = ResultTruncator.truncate(longOutput, policy: policy)
/// // "[Truncated: 45000 chars total, showing last 200]\n...\n<last 200 chars>"
/// ```
public enum ResultTruncator {
    /// Truncates a tool result string if it exceeds the policy's maximum.
    ///
    /// - Parameters:
    ///   - text: The tool result to potentially truncate.
    ///   - policy: The truncation policy to apply.
    /// - Returns: The original text if under the limit, or a truncated version.
    public static func truncate(_ text: String, policy: TruncationPolicy) -> String {
        guard text.count > policy.maxCharacters else { return text }

        let preserveCount = min(policy.preserveLastCharacters, policy.maxCharacters)
        let suffix = String(text.suffix(preserveCount))
        let header = "[Truncated: \(text.count) chars total, showing last \(preserveCount)]"

        return "\(header)\n...\n\(suffix)"
    }

    /// Truncates a file path preserving the first component and filename.
    ///
    /// Useful for displaying long paths in constrained contexts:
    /// `/Users/name/very/long/.../project/file.swift`
    public static func truncatePath(_ path: String, maxLength: Int) -> String {
        guard path.count > maxLength, maxLength > 10 else { return path }

        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count > 2 else { return path }

        let first = components.first!
        let last = components.last!
        let prefix = "/\(first)"
        let suffix = "/\(last)"

        let available = maxLength - prefix.count - suffix.count - 4 // for /...
        if available <= 0 {
            return "\(prefix)/.../\(last)"
        }

        // Try to include intermediate components from the end
        var middle: [Substring] = []
        var used = 0
        for component in components.dropFirst().dropLast().reversed() {
            if used + component.count + 1 <= available {
                middle.insert(component, at: 0)
                used += component.count + 1
            } else {
                break
            }
        }

        if middle.count < components.count - 2 {
            return "\(prefix)/...\(middle.isEmpty ? "" : "/")\(middle.joined(separator: "/"))/\(last)"
        }
        return path
    }
}
