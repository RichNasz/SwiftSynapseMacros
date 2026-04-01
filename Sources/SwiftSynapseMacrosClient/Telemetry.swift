// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Telemetry Event

/// A structured telemetry event emitted during agent execution.
public struct TelemetryEvent: Sendable {
    public let timestamp: Date
    public let kind: TelemetryEventKind
    public let agentType: String
    public let sessionId: String?

    public init(
        kind: TelemetryEventKind,
        agentType: String = "",
        sessionId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.agentType = agentType
        self.sessionId = sessionId
    }
}

/// The kind of telemetry event.
public enum TelemetryEventKind: Sendable {
    case agentStarted(goal: String)
    case agentCompleted(result: String, duration: Duration)
    case agentFailed(error: Error)

    case llmCallMade(model: String, inputTokens: Int, outputTokens: Int, duration: Duration, cacheCreationTokens: Int = 0, cacheReadTokens: Int = 0)

    case toolCalled(name: String, duration: Duration, success: Bool)

    case retryAttempted(error: Error, attempt: Int)

    case tokenBudgetExhausted(used: Int, limit: Int)

    case guardrailTriggered(policy: String, risk: RiskLevel)

    case contextCompacted(entriesBefore: Int, entriesAfter: Int, strategy: String)

    case apiErrorClassified(category: String, model: String?)

    case pluginActivated(name: String)
    case pluginError(name: String, error: Error)
}

// MARK: - Telemetry Sink

/// A destination for telemetry events.
///
/// Implement this protocol to send telemetry to your preferred backend
/// (logging, analytics, monitoring, etc.).
public protocol TelemetrySink: Sendable {
    func emit(_ event: TelemetryEvent)
}

// MARK: - Token Usage Tracker

/// Tracks cumulative token usage across LLM calls within an agent session.
///
/// Thread-safe: all mutations are serialized on the actor's executor.
public actor TokenUsageTracker {
    public private(set) var totalInputTokens: Int = 0
    public private(set) var totalOutputTokens: Int = 0
    public private(set) var callCount: Int = 0

    public init() {}

    /// Records token usage from an LLM call.
    public func record(inputTokens: Int, outputTokens: Int) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        callCount += 1
    }

    /// Total tokens consumed (input + output).
    public var totalTokens: Int { totalInputTokens + totalOutputTokens }

    /// Resets all counters to zero.
    public func reset() {
        totalInputTokens = 0
        totalOutputTokens = 0
        callCount = 0
    }
}
