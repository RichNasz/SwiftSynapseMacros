// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Hook Event Kinds (for subscription filtering)

/// Lightweight enum for subscription filtering without matching associated values.
public enum AgentHookEventKind: Hashable, Sendable {
    case agentStarted
    case agentCompleted
    case agentFailed
    case agentCancelled
    case preToolUse
    case postToolUse
    case llmRequestSent
    case llmResponseReceived
    case transcriptUpdated
    case sessionSaved
    case sessionRestored
    case guardrailTriggered
    case coordinationPhaseStarted
    case coordinationPhaseCompleted
    case memoryUpdated
    case transcriptRepaired
}

// MARK: - Hook Events

/// Events fired during agent and tool execution.
public enum AgentHookEvent: Sendable {
    case agentStarted(goal: String)
    case agentCompleted(result: String)
    case agentFailed(error: Error)
    case agentCancelled

    case preToolUse(calls: [AgentToolCall])
    case postToolUse(results: [ToolResult])

    case llmRequestSent(request: AgentRequest)
    case llmResponseReceived(response: AgentResponse)

    case transcriptUpdated(entry: TranscriptEntry)

    case sessionSaved(sessionId: String)
    case sessionRestored(sessionId: String)

    case guardrailTriggered(policy: String, decision: GuardrailDecision, input: GuardrailInput)

    case coordinationPhaseStarted(phase: String)
    case coordinationPhaseCompleted(phase: String)

    case memoryUpdated(entry: MemoryEntry)
    case transcriptRepaired(violations: [IntegrityViolation])

    /// The kind of this event, for subscription filtering.
    public var kind: AgentHookEventKind {
        switch self {
        case .agentStarted: .agentStarted
        case .agentCompleted: .agentCompleted
        case .agentFailed: .agentFailed
        case .agentCancelled: .agentCancelled
        case .preToolUse: .preToolUse
        case .postToolUse: .postToolUse
        case .llmRequestSent: .llmRequestSent
        case .llmResponseReceived: .llmResponseReceived
        case .transcriptUpdated: .transcriptUpdated
        case .sessionSaved: .sessionSaved
        case .sessionRestored: .sessionRestored
        case .guardrailTriggered: .guardrailTriggered
        case .coordinationPhaseStarted: .coordinationPhaseStarted
        case .coordinationPhaseCompleted: .coordinationPhaseCompleted
        case .memoryUpdated: .memoryUpdated
        case .transcriptRepaired: .transcriptRepaired
        }
    }
}

// MARK: - Hook Action

/// The action a hook returns to control execution flow.
public enum HookAction: Sendable {
    /// Continue execution normally.
    case proceed
    /// Replace the current input/output with a modified value.
    case modify(String)
    /// Abort the current operation with a reason.
    case block(reason: String)
}

// MARK: - Hook Protocol

/// A hook that intercepts agent and tool execution events.
///
/// Implement this protocol to add audit logging, input sanitization,
/// approval gates, or custom error handling to agents.
public protocol AgentHook: Sendable {
    /// The set of events this hook wants to receive.
    var subscribedEvents: Set<AgentHookEventKind> { get }

    /// Called when a subscribed event fires. Return an action to control flow.
    func handle(_ event: AgentHookEvent) async -> HookAction
}

// MARK: - Closure-Based Hook

/// A convenience hook that uses a closure for handling events.
///
/// ```swift
/// let auditHook = ClosureHook(on: [.preToolUse]) { event in
///     if case .preToolUse(let calls) = event {
///         for call in calls {
///             AuditLog.record("Tool invoked: \(call.name)")
///         }
///     }
///     return .proceed
/// }
/// ```
public struct ClosureHook: AgentHook {
    public let subscribedEvents: Set<AgentHookEventKind>
    private let handler: @Sendable (AgentHookEvent) async -> HookAction

    public init(
        on events: Set<AgentHookEventKind>,
        handler: @escaping @Sendable (AgentHookEvent) async -> HookAction
    ) {
        self.subscribedEvents = events
        self.handler = handler
    }

    public func handle(_ event: AgentHookEvent) async -> HookAction {
        await handler(event)
    }
}
