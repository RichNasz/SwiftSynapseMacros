// Generated from CodeGenSpecs/Client-Types.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Lifecycle Errors

/// Errors from the agent lifecycle runtime.
public enum AgentLifecycleError: Error, Sendable {
    /// The goal string was empty.
    case emptyGoal
    /// A hook blocked agent startup.
    case blockedByHook(reason: String)
}

// MARK: - Agent Executable Protocol

/// The protocol that `@SpecDrivenAgent` actors implicitly conform to.
///
/// The macro generates `_status`, `_transcript`, and `run(goal:)`.
/// Users implement `execute(goal:)` with domain logic only.
public protocol AgentExecutable: Actor {
    /// The mutable status backing store (macro-generated).
    var _status: AgentStatus { get set }
    /// The mutable transcript backing store (macro-generated).
    var _transcript: ObservableTranscript { get set }
    /// User-implemented domain logic. Called by the macro-generated `run(goal:)`.
    func execute(goal: String) async throws -> String
}
