// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Subagent Context

/// Configuration inherited by child agents spawned from a parent.
///
/// Controls what the child agent can access (tools, permissions) and
/// how it relates to the parent (shared vs. independent lifecycle).
///
/// ```swift
/// let context = SubagentContext(
///     config: parentConfig,
///     tools: childToolRegistry,
///     hooks: parentHooks,
///     telemetry: parentTelemetry,
///     permissions: parentPermissions,
///     lifecycleMode: .independent
/// )
///
/// let result = try await SubagentRunner.run(
///     agentFactory: { try ChildAgent(configuration: $0) },
///     goal: "Summarize the report",
///     context: context
/// )
/// ```
public struct SubagentContext: Sendable {
    /// The agent configuration (model, retries, timeouts).
    public let config: AgentConfiguration

    /// The tool registry for the child agent. May be a subset of parent's tools.
    public let tools: ToolRegistry?

    /// The hook pipeline inherited from the parent. Optional — child can run without hooks.
    public let hooks: AgentHookPipeline?

    /// The telemetry sink inherited from the parent.
    public let telemetry: (any TelemetrySink)?

    /// How the child agent's lifecycle relates to the parent.
    public let lifecycleMode: SubagentLifecycleMode

    /// Optional system prompt override for the child agent.
    public let systemPrompt: String?

    /// Maximum iterations for the child's tool loop.
    public let maxIterations: Int

    public init(
        config: AgentConfiguration,
        tools: ToolRegistry? = nil,
        hooks: AgentHookPipeline? = nil,
        telemetry: (any TelemetrySink)? = nil,
        lifecycleMode: SubagentLifecycleMode = .independent,
        systemPrompt: String? = nil,
        maxIterations: Int = 10
    ) {
        self.config = config
        self.tools = tools
        self.hooks = hooks
        self.telemetry = telemetry
        self.lifecycleMode = lifecycleMode
        self.systemPrompt = systemPrompt
        self.maxIterations = maxIterations
    }
}

// MARK: - Lifecycle Mode

/// How a child agent's lifecycle relates to its parent.
public enum SubagentLifecycleMode: Sendable {
    /// Child runs independently. Parent cancellation does NOT cancel the child.
    /// Results are collected when the parent awaits.
    case independent

    /// Child shares the parent's cancellation scope.
    /// If the parent is cancelled, the child is cancelled too.
    case shared
}

// MARK: - Subagent Result

/// The result of a subagent execution.
public struct SubagentResult: Sendable {
    /// The final text output from the child agent.
    public let output: String
    /// The child agent's transcript (for inspection/logging).
    public let transcript: [TranscriptEntry]
    /// How long the child agent ran.
    public let duration: Duration
    /// Whether the child completed successfully.
    public let success: Bool

    public init(output: String, transcript: [TranscriptEntry], duration: Duration, success: Bool) {
        self.output = output
        self.transcript = transcript
        self.duration = duration
        self.success = success
    }
}

// MARK: - Subagent Runner

/// Spawns and runs child agents with inherited context.
///
/// The runner handles lifecycle management, context propagation,
/// and result collection for child agents.
///
/// ```swift
/// // Run a child agent synchronously (parent waits for result)
/// let result = try await SubagentRunner.run(
///     agentFactory: { config in try SummaryAgent(configuration: config) },
///     goal: "Summarize this document",
///     context: SubagentContext(config: parentConfig)
/// )
///
/// // Run multiple child agents in parallel
/// let results = try await SubagentRunner.runParallel(
///     agents: [
///         ("Summarize section 1", context),
///         ("Summarize section 2", context),
///     ],
///     agentFactory: { config in try SummaryAgent(configuration: config) }
/// )
/// ```
public enum SubagentRunner {

    /// Runs a single child agent and returns its result.
    ///
    /// - Parameters:
    ///   - agentFactory: A closure that creates the child agent from a configuration.
    ///   - goal: The goal to pass to the child agent.
    ///   - context: The inherited context for the child agent.
    /// - Returns: The child agent's result.
    public static func run<A: AgentExecutable>(
        agentFactory: (AgentConfiguration) throws -> A,
        goal: String,
        context: SubagentContext
    ) async throws -> SubagentResult {
        let start = ContinuousClock.now

        let agent = try agentFactory(context.config)

        // Emit telemetry for subagent start
        context.telemetry?.emit(TelemetryEvent(kind: .agentStarted(goal: goal)))

        do {
            let output: String
            switch context.lifecycleMode {
            case .shared:
                // Shared lifecycle: child inherits parent's task cancellation
                output = try await agentRun(
                    agent: agent,
                    goal: goal,
                    hooks: context.hooks,
                    telemetry: context.telemetry
                )

            case .independent:
                // Independent lifecycle: child runs in its own task
                output = try await Task {
                    try await agentRun(
                        agent: agent,
                        goal: goal,
                        hooks: context.hooks,
                        telemetry: context.telemetry
                    )
                }.value
            }

            let duration = ContinuousClock.now - start
            let transcriptEntries = await agent._transcript.entries

            context.telemetry?.emit(TelemetryEvent(
                kind: .agentCompleted(result: output, duration: duration)
            ))

            return SubagentResult(
                output: output,
                transcript: transcriptEntries,
                duration: duration,
                success: true
            )
        } catch {
            let duration = ContinuousClock.now - start
            let transcriptEntries = await agent._transcript.entries

            context.telemetry?.emit(TelemetryEvent(kind: .agentFailed(error: error)))

            if error is CancellationError {
                return SubagentResult(
                    output: "",
                    transcript: transcriptEntries,
                    duration: duration,
                    success: false
                )
            }
            throw error
        }
    }

    /// Runs multiple child agents in parallel and returns all results.
    ///
    /// All agents use the same factory but receive different goals.
    /// Results are returned in the same order as the input goals.
    ///
    /// - Parameters:
    ///   - agents: Pairs of (goal, context) for each child agent.
    ///   - agentFactory: A closure that creates each child agent.
    /// - Returns: Results in the same order as input goals.
    public static func runParallel<A: AgentExecutable>(
        agents: [(goal: String, context: SubagentContext)],
        agentFactory: @escaping @Sendable (AgentConfiguration) throws -> A
    ) async throws -> [SubagentResult] {
        try await withThrowingTaskGroup(of: (Int, SubagentResult).self) { group in
            for (index, item) in agents.enumerated() {
                group.addTask {
                    let result = try await SubagentRunner.run(
                        agentFactory: agentFactory,
                        goal: item.goal,
                        context: item.context
                    )
                    return (index, result)
                }
            }

            var results = Array(repeating: SubagentResult(
                output: "", transcript: [], duration: .zero, success: false
            ), count: agents.count)

            for try await (index, result) in group {
                results[index] = result
            }

            return results
        }
    }
}
