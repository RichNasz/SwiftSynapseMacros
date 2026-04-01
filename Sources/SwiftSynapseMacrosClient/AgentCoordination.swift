// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Shared Mailbox

/// Cross-agent asynchronous message passing for coordinated workflows.
///
/// Agents in a coordination plan can send and receive messages via named channels.
/// Messages are delivered via `AsyncStream` and consumed in order.
public actor SharedMailbox {
    private var channels: [String: [String]] = [:]
    private var continuations: [String: AsyncStream<String>.Continuation] = [String: AsyncStream<String>.Continuation]()

    public init() {}

    /// Sends a message to the named recipient.
    public func send(to recipient: String, message: String) {
        if let continuation = continuations[recipient] {
            continuation.yield(message)
        } else {
            channels[recipient, default: []].append(message)
        }
    }

    /// Receives messages for the named agent as an async stream.
    public func receive(for agent: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            // Deliver any queued messages
            if let queued = channels.removeValue(forKey: agent) {
                for message in queued {
                    continuation.yield(message)
                }
            }
            continuations[agent] = continuation
        }
    }

    /// Closes all channels.
    public func closeAll() {
        for (_, continuation) in continuations {
            continuation.finish()
        }
        continuations.removeAll()
        channels.removeAll()
    }
}

// MARK: - Team Memory

/// Shared key-value store visible to all agents in a coordination.
///
/// Thread-safe via actor isolation. Supports typed access for common patterns.
public actor TeamMemory {
    private var store: [String: String] = [:]

    public init() {}

    /// Sets a value for the given key.
    public func set(_ key: String, value: String) {
        store[key] = value
    }

    /// Gets a value for the given key.
    public func get(_ key: String) -> String? {
        store[key]
    }

    /// Removes a value for the given key.
    public func remove(_ key: String) {
        store.removeValue(forKey: key)
    }

    /// Returns all key-value pairs.
    public func all() -> [String: String] {
        store
    }

    /// Clears all stored values.
    public func clear() {
        store.removeAll()
    }
}

// MARK: - Coordination Phase

/// A named phase in a coordination plan with dependencies.
///
/// Each phase has a goal template, an agent factory, and a list of phase
/// names that must complete before this phase can start.
public struct CoordinationPhase<A: AgentExecutable>: Sendable {
    /// Unique name for this phase.
    public let name: String

    /// The goal to pass to the agent.
    public let goal: String

    /// Names of phases that must complete before this one starts.
    public let dependencies: [String]

    /// Factory that creates the agent for this phase.
    public let agentFactory: @Sendable (AgentConfiguration) throws -> A

    public init(
        name: String,
        goal: String,
        dependencies: [String] = [],
        agentFactory: @escaping @Sendable (AgentConfiguration) throws -> A
    ) {
        self.name = name
        self.goal = goal
        self.dependencies = dependencies
        self.agentFactory = agentFactory
    }
}

// MARK: - Coordination Result

/// The result of a coordination plan execution.
public struct CoordinationResult: Sendable {
    /// Results keyed by phase name.
    public let phaseResults: [String: SubagentResult]
    /// Total duration of the coordination.
    public let duration: Duration

    public init(phaseResults: [String: SubagentResult], duration: Duration) {
        self.phaseResults = phaseResults
        self.duration = duration
    }
}

// MARK: - Coordination Runner

/// Executes a coordination plan, respecting phase dependencies.
///
/// Phases with no dependencies (or whose dependencies are satisfied) run in parallel.
/// Results from earlier phases are available to later phases via `TeamMemory`.
///
/// ```swift
/// let phases: [CoordinationPhase<MyAgent>] = [
///     CoordinationPhase(name: "research", goal: "Research the topic"),
///     CoordinationPhase(name: "synthesize", goal: "Synthesize findings",
///                       dependencies: ["research"]),
/// ]
///
/// let result = try await CoordinationRunner.run(
///     phases: phases,
///     config: config
/// )
/// ```
public enum CoordinationRunner {
    /// Runs a coordination plan with the given phases.
    public static func run<A: AgentExecutable>(
        phases: [CoordinationPhase<A>],
        config: AgentConfiguration,
        hooks: AgentHookPipeline? = nil,
        telemetry: (any TelemetrySink)? = nil,
        mailbox: SharedMailbox? = nil,
        teamMemory: TeamMemory? = nil
    ) async throws -> CoordinationResult {
        let start = ContinuousClock.now
        let memory = teamMemory ?? TeamMemory()
        var completedPhases: [String: SubagentResult] = [:]

        // Build dependency graph
        let phasesByName = Dictionary(uniqueKeysWithValues: phases.map { ($0.name, $0) })

        // Validate dependencies exist
        for phase in phases {
            for dep in phase.dependencies {
                guard phasesByName[dep] != nil else {
                    throw CoordinationError.unknownDependency(phase: phase.name, dependency: dep)
                }
            }
        }

        // Execute in waves: find phases whose dependencies are all satisfied
        var remaining = Set(phases.map(\.name))

        while !remaining.isEmpty {
            let ready = phases.filter { phase in
                remaining.contains(phase.name) &&
                phase.dependencies.allSatisfy { completedPhases[$0] != nil }
            }

            guard !ready.isEmpty else {
                throw CoordinationError.cyclicDependency(phases: Array(remaining))
            }

            // Fire hook for each phase starting
            if let hooks {
                for phase in ready {
                    await hooks.fire(.coordinationPhaseStarted(phase: phase.name))
                }
            }

            // Run ready phases in parallel
            let results = try await withThrowingTaskGroup(of: (String, SubagentResult).self) { group in
                for phase in ready {
                    let context = SubagentContext(
                        config: config,
                        hooks: hooks,
                        telemetry: telemetry,
                        lifecycleMode: .shared
                    )
                    group.addTask {
                        let result = try await SubagentRunner.run(
                            agentFactory: phase.agentFactory,
                            goal: phase.goal,
                            context: context
                        )
                        return (phase.name, result)
                    }
                }

                var waveResults: [(String, SubagentResult)] = []
                for try await result in group {
                    waveResults.append(result)
                }
                return waveResults
            }

            for (name, result) in results {
                completedPhases[name] = result
                remaining.remove(name)
                // Store result in team memory for downstream phases
                await memory.set("phase_result_\(name)", value: result.output)

                if let hooks {
                    await hooks.fire(.coordinationPhaseCompleted(phase: name))
                }
            }
        }

        let duration = ContinuousClock.now - start
        return CoordinationResult(phaseResults: completedPhases, duration: duration)
    }
}

/// Errors from coordination execution.
public enum CoordinationError: Error, Sendable {
    /// A phase references a dependency that doesn't exist.
    case unknownDependency(phase: String, dependency: String)
    /// The dependency graph contains a cycle.
    case cyclicDependency(phases: [String])
}
