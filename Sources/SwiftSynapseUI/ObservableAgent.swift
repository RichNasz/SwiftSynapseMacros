// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftSynapseMacrosClient

/// A protocol that all `@SpecDrivenAgent` actors conform to.
///
/// SwiftSynapseUI views accept any `ObservableAgent`, making them
/// reusable across all agents in the framework.
///
/// The primary entry point is `run(goal:)`, which handles lifecycle
/// management (status transitions, transcript, error handling).
/// Agent authors implement `execute(goal:)` with domain logic only.
public protocol ObservableAgent: Actor {
    /// The current execution status of the agent.
    var status: AgentStatus { get }

    /// The observable transcript recording all agent activity.
    var transcript: ObservableTranscript { get }

    /// Runs the agent with full lifecycle management (macro-generated).
    ///
    /// Handles status transitions, transcript reset, error wrapping,
    /// and cancellation support. Calls `execute(goal:)` internally.
    func run(goal: String) async throws -> String

    /// Executes the agent's domain logic. Implement this method — do not call it directly.
    ///
    /// Use `run(goal:)` as the public entry point instead.
    func execute(goal: String) async throws -> String
}
