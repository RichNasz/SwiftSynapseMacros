// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Streaming Events

/// Structured events yielded during a streaming LLM response.
///
/// These events allow the tool loop to dispatch tools as their definitions
/// complete in the stream, rather than waiting for the full response.
public enum AgentStreamEvent: Sendable {
    /// A text delta from the LLM's response.
    case textDelta(String)
    /// A complete tool call has been assembled from the stream.
    case toolCall(AgentToolCall)
    /// The response is complete with usage statistics.
    case responseComplete(responseId: String?, inputTokens: Int, outputTokens: Int)
}

// MARK: - Streaming Tool Executor

/// Manages concurrent tool execution during streaming responses.
///
/// As tool calls arrive from the stream, they are queued and dispatched
/// according to concurrency safety rules. Concurrent-safe tools run
/// in parallel; unsafe tools wait for exclusive access.
///
/// Modeled after Claude Code's `StreamingToolExecutor`, adapted for Swift concurrency.
///
/// ```swift
/// let executor = StreamingToolExecutor(tools: registry)
///
/// for try await event in stream {
///     if case .toolCall(let call) = event {
///         executor.enqueue(call)
///     }
/// }
///
/// let results = try await executor.awaitAll()
/// ```
public actor StreamingToolExecutor {
    private let tools: ToolRegistry
    private let hooks: AgentHookPipeline?
    private let telemetry: (any TelemetrySink)?

    /// Tool execution states
    private enum ToolState: Sendable {
        case queued
        case executing
        case completed(ToolResult)
    }

    private var states: [(call: AgentToolCall, state: ToolState)] = []
    private var runningTasks: [Task<ToolResult, Error>] = []

    public init(
        tools: ToolRegistry,
        hooks: AgentHookPipeline? = nil,
        telemetry: (any TelemetrySink)? = nil
    ) {
        self.tools = tools
        self.hooks = hooks
        self.telemetry = telemetry
    }

    /// Enqueues a tool call for execution.
    ///
    /// If the tool is concurrency-safe, execution starts immediately.
    /// If unsafe, it is queued until all safe tools complete.
    public func enqueue(_ call: AgentToolCall) {
        states.append((call: call, state: .queued))
        // Start immediately if safe
        let isSafe = tools.isConcurrencySafe(toolName: call.name)
        if isSafe {
            startExecution(at: states.count - 1)
        }
    }

    /// Waits for all queued and running tools to complete and returns results.
    ///
    /// Unsafe tools are dispatched sequentially after all safe tools finish.
    public func awaitAll() async throws -> [ToolResult] {
        // Wait for all running (safe) tasks
        var results: [ToolResult] = []
        for task in runningTasks {
            let result = try await task.value
            results.append(result)
        }

        // Now dispatch queued (unsafe) tools sequentially
        for i in 0..<states.count {
            if case .queued = states[i].state {
                let call = states[i].call

                // Fire pre-tool hook for individual tool
                if let hooks {
                    let action = await hooks.fire(.preToolUse(calls: [call]))
                    if case .block(let reason) = action {
                        throw ToolDispatchError.blockedByHook(tool: call.name, reason: reason)
                    }
                }

                let result = try await tools.dispatch(
                    name: call.name,
                    callId: call.id,
                    arguments: call.arguments
                )
                states[i].state = .completed(result)
                results.append(result)

                telemetry?.emit(TelemetryEvent(kind: .toolCalled(
                    name: result.name,
                    duration: result.duration,
                    success: result.success
                )))
            }
        }

        return results
    }

    /// Whether any tools have been enqueued.
    public var hasTools: Bool {
        !states.isEmpty
    }

    // MARK: - Private

    private func startExecution(at index: Int) {
        let call = states[index].call
        states[index].state = .executing

        let task = Task<ToolResult, Error> {
            let result = try await self.tools.dispatch(
                name: call.name,
                callId: call.id,
                arguments: call.arguments
            )
            self.telemetry?.emit(TelemetryEvent(kind: .toolCalled(
                name: result.name,
                duration: result.duration,
                success: result.success
            )))
            return result
        }
        runningTasks.append(task)
    }
}

