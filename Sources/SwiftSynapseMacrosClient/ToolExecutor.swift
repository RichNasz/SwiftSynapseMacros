// Generated from CodeGenSpecs/Shared-Tool-Concurrency.md — Do not edit manually. Update spec and re-generate.

import Foundation

/// Schedules tool calls respecting concurrency safety declarations and returns results in receive order.
public actor ToolExecutor {

    public init() {}

    /// A tool call to be executed.
    public struct ToolCall: Sendable {
        public let name: String
        public let arguments: String
        public let index: Int
        public let isConcurrencySafe: Bool

        public init(name: String, arguments: String, index: Int, isConcurrencySafe: Bool = true) {
            self.name = name
            self.arguments = arguments
            self.index = index
            self.isConcurrencySafe = isConcurrencySafe
        }
    }

    /// Result of a single tool call execution.
    public struct ToolResult: Sendable {
        public let index: Int
        public let name: String
        public let result: String
        public let duration: Duration
    }

    /// Executes tool calls, running concurrent-safe tools in parallel and exclusive tools sequentially.
    ///
    /// Results are always returned sorted by `index` (receive order), regardless of completion order.
    ///
    /// - Parameters:
    ///   - calls: The tool calls to execute, each with a receive-order index.
    ///   - dispatch: Closure that executes a tool given its name and arguments JSON.
    /// - Returns: Results sorted by receive index.
    public func execute(
        calls: [ToolCall],
        dispatch: @escaping @Sendable (String, String) async throws -> String
    ) async throws -> [ToolResult] {
        let concurrent = calls.filter(\.isConcurrencySafe)
        let exclusive = calls.filter { !$0.isConcurrencySafe }

        var results: [ToolResult] = []

        if !concurrent.isEmpty {
            let concurrentResults = try await withThrowingTaskGroup(
                of: ToolResult.self
            ) { group in
                for call in concurrent {
                    group.addTask {
                        let clock = ContinuousClock()
                        let start = clock.now
                        let result = try await dispatch(call.name, call.arguments)
                        let duration = clock.now - start
                        return ToolResult(index: call.index, name: call.name, result: result, duration: duration)
                    }
                }
                var collected: [ToolResult] = []
                for try await result in group {
                    collected.append(result)
                }
                return collected
            }
            results.append(contentsOf: concurrentResults)
        }

        for call in exclusive {
            let clock = ContinuousClock()
            let start = clock.now
            let result = try await dispatch(call.name, call.arguments)
            let duration = clock.now - start
            results.append(ToolResult(index: call.index, name: call.name, result: result, duration: duration))
        }

        return results.sorted { $0.index < $1.index }
    }

    /// Truncates a tool result string to fit within a token budget.
    ///
    /// Approximation: 1 token ≈ 4 characters. A budget of 0 disables truncation.
    public static func budget(_ result: String, limit: Int) -> String {
        guard limit > 0 else { return result }
        let charLimit = limit * 4
        guard result.count > charLimit else { return result }
        return String(result.prefix(charLimit)) + "\n[TRUNCATED — tool result exceeded \(limit) token budget]"
    }
}
