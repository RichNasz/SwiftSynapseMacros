// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Recovery Context

/// Mutable state tracking which recovery strategies have been attempted.
///
/// Prevents infinite loops by ensuring each strategy is tried at most once.
/// Passed through the tool loop and updated as strategies fire.
public struct RecoveryState: Sendable {
    /// Whether reactive compaction has been attempted.
    public var hasAttemptedCompaction: Bool = false
    /// Whether output token escalation has been attempted.
    public var hasAttemptedTokenEscalation: Bool = false
    /// Whether a continuation prompt has been sent.
    public var hasAttemptedContinuation: Bool = false
    /// The current max output tokens override (nil = use default).
    public var maxOutputTokensOverride: Int? = nil
    /// Number of recovery attempts total.
    public var recoveryCount: Int = 0
    /// Maximum recovery attempts before giving up.
    public let maxRecoveryAttempts: Int

    public init(maxRecoveryAttempts: Int = 3) {
        self.maxRecoveryAttempts = maxRecoveryAttempts
    }

    /// Whether any more recovery attempts are allowed.
    public var canRecover: Bool {
        recoveryCount < maxRecoveryAttempts
    }
}

// MARK: - Recovery Errors

/// Errors that can trigger recovery strategies.
public enum RecoverableError: Sendable {
    /// The LLM's context window was exceeded.
    case contextWindowExceeded
    /// The LLM's output was truncated (hit max_output_tokens).
    case outputTruncated
    /// A transient API error occurred after retries were exhausted.
    case apiError(Error)
}

// MARK: - Recovery Strategy Protocol

/// A strategy for recovering from errors during the tool loop.
///
/// Strategies are tried in order. Each strategy examines the error and recovery
/// state, then either handles recovery (returning `.recovered`) or passes
/// (returning `.cannotRecover`).
public protocol RecoveryStrategy: Sendable {
    /// Attempts to recover from an error.
    ///
    /// - Parameters:
    ///   - error: The classified recoverable error.
    ///   - state: Mutable recovery state (update to mark this strategy as attempted).
    ///   - transcript: The current transcript (may be compressed during recovery).
    ///   - compressor: Optional transcript compressor.
    ///   - budget: Optional context budget.
    /// - Returns: `.recovered` with an optional continuation prompt, or `.cannotRecover`.
    func attemptRecovery(
        from error: RecoverableError,
        state: inout RecoveryState,
        transcript: ObservableTranscript,
        compressor: (any TranscriptCompressor)?,
        budget: inout ContextBudget?
    ) async throws -> RecoveryResult
}

/// The result of a recovery attempt.
public enum RecoveryResult: Sendable {
    /// Recovery succeeded. Optionally includes a continuation prompt to send to the LLM.
    case recovered(continuationPrompt: String?)
    /// This strategy cannot handle this error.
    case cannotRecover
}

// MARK: - Built-In Strategies

/// Compresses the transcript when the context window is exceeded.
///
/// This is the cheapest recovery: it removes older messages to free up context.
/// Tried first before more expensive strategies.
public struct ReactiveCompactionStrategy: RecoveryStrategy {
    public init() {}

    public func attemptRecovery(
        from error: RecoverableError,
        state: inout RecoveryState,
        transcript: ObservableTranscript,
        compressor: (any TranscriptCompressor)?,
        budget: inout ContextBudget?
    ) async throws -> RecoveryResult {
        guard case .contextWindowExceeded = error else { return .cannotRecover }
        guard !state.hasAttemptedCompaction else { return .cannotRecover }
        guard let compressor else { return .cannotRecover }

        state.hasAttemptedCompaction = true
        state.recoveryCount += 1

        let compressed = try await compressor.compress(
            entries: transcript.entries,
            budget: budget ?? ContextBudget(maxTokens: Int.max)
        )
        transcript.sync(from: compressed)

        return .recovered(continuationPrompt: nil)
    }
}

/// Increases the max output tokens when the LLM's response was truncated.
///
/// Some APIs truncate responses at a default limit (e.g., 4096 tokens).
/// This strategy escalates to a higher limit on the retry.
public struct OutputTokenEscalationStrategy: RecoveryStrategy {
    /// The escalated token limit to use on retry.
    public let escalatedLimit: Int

    public init(escalatedLimit: Int = 16384) {
        self.escalatedLimit = escalatedLimit
    }

    public func attemptRecovery(
        from error: RecoverableError,
        state: inout RecoveryState,
        transcript: ObservableTranscript,
        compressor: (any TranscriptCompressor)?,
        budget: inout ContextBudget?
    ) async throws -> RecoveryResult {
        guard case .outputTruncated = error else { return .cannotRecover }
        guard !state.hasAttemptedTokenEscalation else { return .cannotRecover }

        state.hasAttemptedTokenEscalation = true
        state.maxOutputTokensOverride = escalatedLimit
        state.recoveryCount += 1

        return .recovered(continuationPrompt: nil)
    }
}

/// Sends a continuation prompt when the LLM stopped mid-response.
///
/// Appends a message asking the LLM to continue from where it left off.
/// Useful when the model hits output limits but has more to say.
public struct ContinuationStrategy: RecoveryStrategy {
    /// The prompt sent to ask the LLM to continue.
    public let continuationPrompt: String

    public init(continuationPrompt: String = "Please continue from where you left off.") {
        self.continuationPrompt = continuationPrompt
    }

    public func attemptRecovery(
        from error: RecoverableError,
        state: inout RecoveryState,
        transcript: ObservableTranscript,
        compressor: (any TranscriptCompressor)?,
        budget: inout ContextBudget?
    ) async throws -> RecoveryResult {
        guard case .outputTruncated = error else { return .cannotRecover }
        guard !state.hasAttemptedContinuation else { return .cannotRecover }

        state.hasAttemptedContinuation = true
        state.recoveryCount += 1

        return .recovered(continuationPrompt: continuationPrompt)
    }
}

// MARK: - Recovery Chain

/// An ordered chain of recovery strategies tried in sequence.
///
/// The first strategy that returns `.recovered` wins. If all strategies
/// return `.cannotRecover`, the original error is rethrown.
///
/// ```swift
/// let recovery = RecoveryChain(strategies: [
///     ReactiveCompactionStrategy(),
///     OutputTokenEscalationStrategy(escalatedLimit: 16384),
///     ContinuationStrategy(),
/// ])
/// ```
public struct RecoveryChain: Sendable {
    private let strategies: [any RecoveryStrategy]

    public init(strategies: [any RecoveryStrategy]) {
        self.strategies = strategies
    }

    /// The default recovery chain for most agents.
    public static var `default`: RecoveryChain {
        RecoveryChain(strategies: [
            ReactiveCompactionStrategy(),
            OutputTokenEscalationStrategy(),
            ContinuationStrategy(),
        ])
    }

    /// Attempts recovery using each strategy in order.
    public func attemptRecovery(
        from error: RecoverableError,
        state: inout RecoveryState,
        transcript: ObservableTranscript,
        compressor: (any TranscriptCompressor)?,
        budget: inout ContextBudget?
    ) async throws -> RecoveryResult {
        guard state.canRecover else { return .cannotRecover }

        for strategy in strategies {
            let result = try await strategy.attemptRecovery(
                from: error,
                state: &state,
                transcript: transcript,
                compressor: compressor,
                budget: &budget
            )
            if case .recovered = result {
                return result
            }
        }
        return .cannotRecover
    }
}

// MARK: - Error Classification

/// Classifies an error as recoverable or not.
///
/// Delegates to `classifyAPIError()` for semantic classification, then maps
/// relevant categories to `RecoverableError` cases.
public func classifyRecoverableError(_ error: Error) -> RecoverableError? {
    let classified = classifyAPIError(error)

    // Check for context window exhaustion via error description
    let description = String(describing: error).lowercased()
    if description.contains("context_length_exceeded")
        || description.contains("context window")
        || description.contains("maximum context length")
        || description.contains("too many tokens") {
        return .contextWindowExceeded
    }

    // Check for output truncation
    if description.contains("max_tokens")
        || description.contains("length_limit")
        || description.contains("output truncated")
        || description.contains("maximum output") {
        return .outputTruncated
    }

    // Map retryable API errors to apiError for recovery
    if classified.isRetryable {
        return .apiError(error)
    }

    return nil
}
