// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Compaction Trigger

/// Configures when transcript compression fires in the tool loop.
public enum CompactionTrigger: Sendable {
    /// Triggers when budget utilization exceeds the given percentage (0.0–1.0).
    case threshold(Double)
    /// Triggers when total token count exceeds this value.
    case tokenCount(Int)
    /// Triggers when transcript entry count exceeds this value.
    case entryCount(Int)
    /// Never auto-triggers; compression must be invoked manually.
    case manual

    /// The default trigger: 80% budget utilization.
    public static var `default`: CompactionTrigger { .threshold(0.8) }

    /// Evaluates whether compaction should trigger given the current state.
    public func shouldCompact(budget: ContextBudget?, entryCount: Int) -> Bool {
        switch self {
        case .threshold(let pct):
            guard let budget else { return false }
            return budget.utilizationPercentage > pct
        case .tokenCount(let limit):
            guard let budget else { return false }
            return budget.usedTokens > limit
        case .entryCount(let limit):
            return entryCount > limit
        case .manual:
            return false
        }
    }
}

// MARK: - Micro Compactor

/// Truncates individual tool results that exceed a configurable character limit.
///
/// Runs before other compressors to reduce oversized individual entries without
/// affecting the overall transcript structure.
public struct MicroCompactor: TranscriptCompressor {
    /// Maximum character length for a single tool result.
    public let maxResultLength: Int

    public init(maxResultLength: Int = 2048) {
        self.maxResultLength = maxResultLength
    }

    public func compress(entries: [TranscriptEntry], budget: ContextBudget) async throws -> [TranscriptEntry] {
        entries.map { entry in
            switch entry {
            case .toolResult(let name, let result, let duration):
                if result.count > maxResultLength {
                    let truncated = String(result.prefix(maxResultLength))
                    return .toolResult(
                        name: name,
                        result: "\(truncated)\n[Truncated: \(result.count) chars → \(maxResultLength) chars]",
                        duration: duration
                    )
                }
                return entry
            default:
                return entry
            }
        }
    }
}

// MARK: - Importance Compressor

/// Drops entries by importance score when the transcript needs compression.
///
/// Scores entries by type: user messages are most important, tool results
/// least important. Drops lowest-scored entries first until within budget.
public struct ImportanceCompressor: TranscriptCompressor {
    /// How many entries to keep at minimum.
    public let minimumEntries: Int

    /// Custom scoring function. Higher scores are preserved.
    public let scoringFunction: @Sendable (TranscriptEntry) -> Double

    /// Creates an importance compressor with default scoring.
    public init(minimumEntries: Int = 6) {
        self.minimumEntries = minimumEntries
        self.scoringFunction = Self.defaultScore
    }

    /// Creates an importance compressor with a custom scoring function.
    public init(minimumEntries: Int = 6, scoring: @escaping @Sendable (TranscriptEntry) -> Double) {
        self.minimumEntries = minimumEntries
        self.scoringFunction = scoring
    }

    public func compress(entries: [TranscriptEntry], budget: ContextBudget) async throws -> [TranscriptEntry] {
        guard entries.count > minimumEntries else { return entries }

        // Score and sort, preserving indices
        let scored = entries.enumerated().map { (index: $0.offset, entry: $0.element, score: scoringFunction($0.element)) }

        // Always keep first (user message) and last few entries
        let keepFirst = 1
        let keepLast = max(2, minimumEntries / 2)
        let protectedIndices = Set(
            Array(0..<keepFirst) + Array(max(0, entries.count - keepLast)..<entries.count)
        )

        // Sort unprotected entries by score (ascending = least important first)
        let unprotected = scored.filter { !protectedIndices.contains($0.index) }
            .sorted { $0.score < $1.score }

        // Drop entries until we're at minimumEntries
        let toDrop = max(0, entries.count - minimumEntries)
        let dropIndices = Set(unprotected.prefix(toDrop).map { $0.index })

        let dropped = dropIndices.count
        var result = scored
            .filter { !dropIndices.contains($0.index) }
            .map { $0.entry }

        if dropped > 0 {
            // Insert summary at the beginning after the first entry
            let summary = TranscriptEntry.assistantMessage(
                "[Context compressed: \(dropped) lower-priority message\(dropped == 1 ? "" : "s") omitted]"
            )
            if result.count > 1 {
                result.insert(summary, at: 1)
            } else {
                result.append(summary)
            }
        }

        return result
    }

    /// Default scoring: user messages > assistant messages > tool calls > tool results.
    public static func defaultScore(_ entry: TranscriptEntry) -> Double {
        switch entry {
        case .userMessage: 1.0
        case .assistantMessage: 0.8
        case .reasoning: 0.5
        case .toolCall: 0.4
        case .toolResult: 0.3
        case .error: 0.9
        }
    }
}

// MARK: - Auto Compact Compressor

/// Aggressively compresses transcript when budget utilization is high.
///
/// Keeps the system prompt context (first entry) and the last N entries,
/// replacing everything in between with a single summary message.
public struct AutoCompactCompressor: TranscriptCompressor {
    /// Number of recent entries to preserve.
    public let keepLast: Int

    public init(keepLast: Int = 6) {
        self.keepLast = keepLast
    }

    public func compress(entries: [TranscriptEntry], budget: ContextBudget) async throws -> [TranscriptEntry] {
        guard entries.count > keepLast + 1 else { return entries }

        let first = entries[0]
        let recent = Array(entries.suffix(keepLast))
        let dropped = entries.count - keepLast - 1

        let summary = TranscriptEntry.assistantMessage(
            "[Auto-compacted: \(dropped) message\(dropped == 1 ? "" : "s") compressed to reduce context usage from \(Int(budget.utilizationPercentage * 100))%]"
        )

        return [first, summary] + recent
    }
}

// MARK: - Composite Compressor

/// Chains multiple compressors in order, applying each one's output to the next.
///
/// Typical chain: MicroCompactor → ImportanceCompressor → SlidingWindowCompressor.
public struct CompositeCompressor: TranscriptCompressor {
    private let compressors: [any TranscriptCompressor]

    /// Creates a composite compressor with the given chain.
    public init(_ compressors: [any TranscriptCompressor]) {
        self.compressors = compressors
    }

    /// A default composite compressor chain.
    public static var `default`: CompositeCompressor {
        CompositeCompressor([
            MicroCompactor(),
            ImportanceCompressor(),
            SlidingWindowCompressor(keepLast: 10),
        ])
    }

    public func compress(entries: [TranscriptEntry], budget: ContextBudget) async throws -> [TranscriptEntry] {
        var result = entries
        for compressor in compressors {
            result = try await compressor.compress(entries: result, budget: budget)
        }
        return result
    }
}
