// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Model Pricing

/// Per-model token pricing for cost calculation.
///
/// Costs are expressed per million tokens. Set pricing for each model
/// your agents use via `CostTracker.setPricing(for:pricing:)`.
public struct ModelPricing: Sendable {
    /// Cost per million input tokens.
    public let inputCostPerMillionTokens: Decimal
    /// Cost per million output tokens.
    public let outputCostPerMillionTokens: Decimal
    /// Cost per million cache creation tokens (prompt caching).
    public let cacheCreationCostPerMillionTokens: Decimal
    /// Cost per million cache read tokens (prompt caching).
    public let cacheReadCostPerMillionTokens: Decimal

    public init(
        inputCostPerMillionTokens: Decimal,
        outputCostPerMillionTokens: Decimal,
        cacheCreationCostPerMillionTokens: Decimal = 0,
        cacheReadCostPerMillionTokens: Decimal = 0
    ) {
        self.inputCostPerMillionTokens = inputCostPerMillionTokens
        self.outputCostPerMillionTokens = outputCostPerMillionTokens
        self.cacheCreationCostPerMillionTokens = cacheCreationCostPerMillionTokens
        self.cacheReadCostPerMillionTokens = cacheReadCostPerMillionTokens
    }

    /// Calculates the cost for the given token counts.
    public func cost(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0
    ) -> Decimal {
        let million: Decimal = 1_000_000
        return (Decimal(inputTokens) * inputCostPerMillionTokens / million)
            + (Decimal(outputTokens) * outputCostPerMillionTokens / million)
            + (Decimal(cacheCreationTokens) * cacheCreationCostPerMillionTokens / million)
            + (Decimal(cacheReadTokens) * cacheReadCostPerMillionTokens / million)
    }
}

// MARK: - Cost Record

/// A single LLM call cost record.
public struct CostRecord: Sendable {
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let cost: Decimal
    public let apiDuration: Duration
    public let timestamp: Date

    public init(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cost: Decimal,
        apiDuration: Duration,
        timestamp: Date = Date()
    ) {
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.cost = cost
        self.apiDuration = apiDuration
        self.timestamp = timestamp
    }
}

// MARK: - Model Usage

/// Aggregated per-model usage summary.
public struct ModelUsage: Sendable {
    public let model: String
    public var totalInputTokens: Int
    public var totalOutputTokens: Int
    public var totalCacheCreationTokens: Int
    public var totalCacheReadTokens: Int
    public var totalCost: Decimal
    public var callCount: Int

    public init(model: String) {
        self.model = model
        self.totalInputTokens = 0
        self.totalOutputTokens = 0
        self.totalCacheCreationTokens = 0
        self.totalCacheReadTokens = 0
        self.totalCost = 0
        self.callCount = 0
    }

    public var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }
}

// MARK: - Cost Tracker

/// Tracks cumulative costs across LLM calls within an agent session.
///
/// Configure pricing per model, then record each LLM call. Query totals
/// at any point for cost monitoring, budgeting, or billing.
///
/// ```swift
/// let tracker = CostTracker()
/// await tracker.setPricing(for: "claude-sonnet-4-20250514", pricing: ModelPricing(
///     inputCostPerMillionTokens: 3,
///     outputCostPerMillionTokens: 15
/// ))
///
/// // Records accumulate automatically via CostTrackingTelemetrySink
/// let total = await tracker.totalCost()
/// ```
public actor CostTracker {
    private var records: [CostRecord] = []
    private var pricingTable: [String: ModelPricing] = [:]

    public init() {}

    /// Sets pricing for a specific model.
    public func setPricing(for model: String, pricing: ModelPricing) {
        pricingTable[model] = pricing
    }

    /// Records an LLM call with automatic cost calculation.
    public func record(
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0,
        apiDuration: Duration
    ) {
        let pricing = pricingTable[model]
        let cost = pricing?.cost(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        ) ?? 0

        let record = CostRecord(
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost,
            apiDuration: apiDuration
        )
        records.append(record)
    }

    /// Total cost across all recorded LLM calls.
    public func totalCost() -> Decimal {
        records.reduce(0) { $0 + $1.cost }
    }

    /// Total API duration across all recorded LLM calls.
    public func totalAPIDuration() -> Duration {
        records.reduce(Duration.zero) { $0 + $1.apiDuration }
    }

    /// Aggregated usage broken down by model.
    public func usageByModel() -> [String: ModelUsage] {
        var result: [String: ModelUsage] = [:]
        for record in records {
            var usage = result[record.model] ?? ModelUsage(model: record.model)
            usage.totalInputTokens += record.inputTokens
            usage.totalOutputTokens += record.outputTokens
            usage.totalCacheCreationTokens += record.cacheCreationTokens
            usage.totalCacheReadTokens += record.cacheReadTokens
            usage.totalCost += record.cost
            usage.callCount += 1
            result[record.model] = usage
        }
        return result
    }

    /// All recorded cost records.
    public func allRecords() -> [CostRecord] {
        records
    }

    /// Total number of LLM calls recorded.
    public var callCount: Int {
        records.count
    }

    /// Resets all records.
    public func reset() {
        records.removeAll()
    }
}

// MARK: - Cost Tracking Telemetry Sink

/// A telemetry sink that automatically records costs from `.llmCallMade` events.
///
/// Wire this into your telemetry pipeline to accumulate costs without
/// changing any agent or tool loop code:
///
/// ```swift
/// let costTracker = CostTracker()
/// let sink = CostTrackingTelemetrySink(tracker: costTracker)
/// let telemetry = CompositeTelemetrySink([sink, OSLogTelemetrySink()])
/// ```
public struct CostTrackingTelemetrySink: TelemetrySink {
    private let tracker: CostTracker

    public init(tracker: CostTracker) {
        self.tracker = tracker
    }

    public func emit(_ event: TelemetryEvent) {
        if case .llmCallMade(let model, let inputTokens, let outputTokens, let duration,
                             let cacheCreation, let cacheRead) = event.kind {
            Task {
                await tracker.record(
                    model: model,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheCreationTokens: cacheCreation,
                    cacheReadTokens: cacheRead,
                    apiDuration: duration
                )
            }
        }
    }
}
