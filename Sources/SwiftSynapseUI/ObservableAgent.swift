// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftSynapseMacrosClient

/// A protocol that all `@SpecDrivenAgent` actors conform to.
///
/// SwiftSynapseUI views accept any `ObservableAgent`, making them
/// reusable across all agents in the framework.
public protocol ObservableAgent: Actor {
    /// The current execution status of the agent.
    var status: AgentStatus { get }

    /// The observable transcript recording all agent activity.
    var transcript: ObservableTranscript { get }

    /// Executes the agent with the given goal and returns the result.
    func execute(goal: String) async throws -> String
}
