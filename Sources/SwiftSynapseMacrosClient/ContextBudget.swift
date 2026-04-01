// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Context Budget

/// Tracks token usage against a maximum budget for context window management.
///
/// Use with `AgentToolLoop.run()` to automatically trigger transcript compression
/// when the budget approaches exhaustion.
public struct ContextBudget: Sendable {
    /// Maximum tokens allowed in the context window.
    public let maxTokens: Int

    /// Tokens consumed so far.
    public private(set) var usedTokens: Int = 0

    public init(maxTokens: Int) {
        self.maxTokens = maxTokens
    }

    /// Remaining tokens in the budget.
    public var remainingTokens: Int { max(0, maxTokens - usedTokens) }

    /// Whether the budget has been fully consumed.
    public var isExhausted: Bool { usedTokens >= maxTokens }

    /// Current utilization as a percentage (0.0 to 1.0+).
    public var utilizationPercentage: Double {
        guard maxTokens > 0 else { return 1.0 }
        return Double(usedTokens) / Double(maxTokens)
    }

    /// Records token usage from an LLM call.
    public mutating func record(inputTokens: Int, outputTokens: Int) {
        usedTokens += inputTokens + outputTokens
    }

    /// Resets the usage counter.
    public mutating func reset() {
        usedTokens = 0
    }
}

// MARK: - Context Budget Error

/// Errors from context budget management.
public enum ContextBudgetError: Error, Sendable {
    /// The token budget has been fully consumed.
    case exhausted(used: Int, limit: Int)
}

// MARK: - Transcript Compressor

/// Compresses transcript entries when the context budget is running low.
///
/// Implement this protocol to provide custom compression strategies
/// (summarization, sliding window, importance-based pruning, etc.).
public protocol TranscriptCompressor: Sendable {
    /// Compresses transcript entries to fit within the remaining budget.
    ///
    /// - Parameters:
    ///   - entries: The current transcript entries.
    ///   - budget: The current context budget state.
    /// - Returns: A compressed list of entries preserving essential context.
    func compress(entries: [TranscriptEntry], budget: ContextBudget) async throws -> [TranscriptEntry]
}

// MARK: - Sliding Window Compressor

/// A simple compressor that keeps the last N entries and summarizes dropped ones.
///
/// Suitable for most business agents where recent context is more important
/// than early conversation history.
public struct SlidingWindowCompressor: TranscriptCompressor {
    /// Number of recent entries to preserve.
    public let keepLast: Int

    public init(keepLast: Int = 10) {
        self.keepLast = keepLast
    }

    public func compress(entries: [TranscriptEntry], budget: ContextBudget) async throws -> [TranscriptEntry] {
        guard entries.count > keepLast else { return entries }

        let dropped = entries.count - keepLast
        let summary = TranscriptEntry.assistantMessage(
            "[Context compressed: \(dropped) earlier message\(dropped == 1 ? "" : "s") omitted]"
        )
        return [summary] + entries.suffix(keepLast)
    }
}
