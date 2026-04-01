// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation
import os

// MARK: - OS Log Sink

/// Logs telemetry events to the unified logging system (os_log).
public struct OSLogTelemetrySink: TelemetrySink {
    private let logger: Logger

    public init(subsystem: String = "com.swiftsynapse", category: String = "telemetry") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func emit(_ event: TelemetryEvent) {
        switch event.kind {
        case .agentStarted(let goal):
            logger.info("Agent started: \(goal, privacy: .public)")
        case .agentCompleted(_, let duration):
            logger.info("Agent completed in \(duration, privacy: .public)")
        case .agentFailed(let error):
            logger.error("Agent failed: \(error.localizedDescription, privacy: .public)")
        case .llmCallMade(let model, let input, let output, let duration):
            logger.info("LLM call [\(model, privacy: .public)] tokens: \(input)+\(output) in \(duration, privacy: .public)")
        case .toolCalled(let name, let duration, let success):
            logger.info("Tool \(name, privacy: .public) \(success ? "succeeded" : "failed") in \(duration, privacy: .public)")
        case .retryAttempted(let error, let attempt):
            logger.warning("Retry attempt \(attempt): \(error.localizedDescription, privacy: .public)")
        case .tokenBudgetExhausted(let used, let limit):
            logger.warning("Token budget exhausted: \(used)/\(limit)")
        }
    }
}

// MARK: - In-Memory Sink

/// Collects telemetry events in memory for testing and inspection.
///
/// **Note:** `emit()` is synchronous (per `TelemetrySink` protocol) and bridges
/// to the actor via `Task`. Events are guaranteed to be appended without data
/// races, but ordering is best-effort when emitted from multiple concurrent
/// contexts. Use `drain()` from an `await` context for reliable reads.
public actor InMemoryTelemetrySink: TelemetrySink {
    public private(set) var events: [TelemetryEvent] = []

    public init() {}

    nonisolated public func emit(_ event: TelemetryEvent) {
        Task { await self.append(event) }
    }

    private func append(_ event: TelemetryEvent) {
        events.append(event)
    }

    /// Returns all collected events and clears the buffer.
    public func drain() -> [TelemetryEvent] {
        let result = events
        events = []
        return result
    }
}

// MARK: - Composite Sink

/// Multiplexes telemetry events to multiple sinks.
public struct CompositeTelemetrySink: TelemetrySink {
    private let sinks: [any TelemetrySink]

    public init(_ sinks: [any TelemetrySink]) {
        self.sinks = sinks
    }

    public func emit(_ event: TelemetryEvent) {
        for sink in sinks {
            sink.emit(event)
        }
    }
}
