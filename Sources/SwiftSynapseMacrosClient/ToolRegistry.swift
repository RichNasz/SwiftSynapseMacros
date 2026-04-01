// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

/// A registry of agent tools with typed dispatch and concurrency-aware batch execution.
///
/// Register tools conforming to `AgentToolProtocol`, then use `dispatch` or
/// `dispatchBatch` to execute them. The registry handles JSON serialization,
/// concurrency safety classification, and optional permission checks.
///
/// **Thread safety:** All access to the tool dictionary is serialized via a lock.
/// Registration is expected at initialization; dispatch may happen concurrently.
///
/// ```swift
/// let registry = ToolRegistry()
/// registry.register(CalculateTool())
/// registry.register(LookupTool())
///
/// let result = try await registry.dispatch(
///     name: "calculate",
///     callId: "call_1",
///     arguments: "{\"expression\": \"2+2\"}"
/// )
/// ```
public final class ToolRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var _tools: [String: AnyAgentTool] = [:]

    /// Optional permission gate checked before each tool execution.
    public var permissionGate: PermissionGate?

    public init() {}

    /// Registers a tool in the registry. Call during initialization before dispatch.
    public func register<T: AgentToolProtocol>(_ tool: T) {
        lock.lock()
        defer { lock.unlock() }
        _tools[T.name] = AnyAgentTool(tool)
    }

    /// Returns the function definitions for all registered tools (for LLM requests).
    public func definitions() -> [FunctionToolParam] {
        lock.lock()
        defer { lock.unlock() }
        return _tools.values.map { $0.definition }
    }

    /// The names of all registered tools.
    public var toolNames: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(_tools.keys)
    }

    /// Whether any tools are registered.
    public var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _tools.isEmpty
    }

    func tool(named name: String) -> AnyAgentTool? {
        lock.lock()
        defer { lock.unlock() }
        return _tools[name]
    }

    /// Checks if a tool is marked as concurrency-safe.
    public func isConcurrencySafe(toolName: String) -> Bool {
        tool(named: toolName)?.isConcurrencySafe ?? false
    }

    /// Dispatches a single tool call by name with optional progress reporting.
    public func dispatch(
        name: String,
        callId: String,
        arguments: String,
        progressDelegate: (any ToolProgressDelegate)? = nil
    ) async throws -> ToolResult {
        guard let tool = tool(named: name) else {
            throw ToolDispatchError.unknownTool(name)
        }

        // Check permissions if a gate is configured
        if let gate = permissionGate {
            try await gate.check(toolName: name, arguments: arguments)
        }

        let start = ContinuousClock.now
        do {
            let output: String
            if let delegate = progressDelegate {
                output = try await tool.execute(arguments: arguments, callId: callId, progress: delegate)
            } else {
                output = try await tool.execute(arguments: arguments)
            }
            let duration = ContinuousClock.now - start
            return ToolResult(callId: callId, name: name, output: output, duration: duration, success: true)
        } catch let error as ToolDispatchError {
            // Rethrow dispatch errors (decoding/encoding failures) — don't mask them
            throw error
        } catch let error as PermissionError {
            // Rethrow permission errors — the caller needs to know
            throw error
        } catch {
            let duration = ContinuousClock.now - start
            return ToolResult(
                callId: callId,
                name: name,
                output: "Error: \(error.localizedDescription)",
                duration: duration,
                success: false
            )
        }
    }

    /// Dispatches multiple tool calls, running concurrency-safe tools in parallel.
    ///
    /// Tools marked as `isConcurrencySafe` run in a `TaskGroup`. Unsafe tools
    /// run sequentially after all safe tools complete.
    public func dispatchBatch(
        _ calls: [AgentToolCall],
        progressDelegate: (any ToolProgressDelegate)? = nil
    ) async throws -> [ToolResult] {
        var safeCalls: [AgentToolCall] = []
        var unsafeCalls: [AgentToolCall] = []

        for call in calls {
            guard let t = tool(named: call.name) else {
                throw ToolDispatchError.unknownTool(call.name)
            }
            if t.isConcurrencySafe {
                safeCalls.append(call)
            } else {
                unsafeCalls.append(call)
            }
        }

        var results: [ToolResult] = []

        // Run safe tools in parallel
        if !safeCalls.isEmpty {
            let safeResults = try await withThrowingTaskGroup(of: ToolResult.self) { group in
                for call in safeCalls {
                    group.addTask {
                        try await self.dispatch(name: call.name, callId: call.id, arguments: call.arguments, progressDelegate: progressDelegate)
                    }
                }
                var collected: [ToolResult] = []
                for try await result in group {
                    collected.append(result)
                }
                return collected
            }
            results.append(contentsOf: safeResults)
        }

        // Run unsafe tools sequentially
        for call in unsafeCalls {
            let result = try await dispatch(name: call.name, callId: call.id, arguments: call.arguments, progressDelegate: progressDelegate)
            results.append(result)
        }

        return results
    }
}
