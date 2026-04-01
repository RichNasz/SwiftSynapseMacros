// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

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

// MARK: - Agent Runtime

/// Orchestrates agent lifecycle: status transitions, transcript management,
/// error handling, cancellation support, and hook/telemetry integration.
///
/// Called by the macro-generated `run(goal:)` method. Not intended for
/// direct use by agent authors.
public func agentRun<A: AgentExecutable>(
    agent: isolated A,
    goal: String,
    hooks: AgentHookPipeline? = nil,
    telemetry: (any TelemetrySink)? = nil,
    sessionStore: (any SessionStore)? = nil,
    sessionAgentType: String? = nil
) async throws -> String {
    // 1. Validate
    guard !goal.isEmpty else {
        let error = AgentLifecycleError.emptyGoal
        agent._status = .error(error)
        throw error
    }

    // 2. Start
    agent._status = .running
    agent._transcript.reset()

    if let hooks {
        let action = await hooks.fire(.agentStarted(goal: goal))
        if case .block(let reason) = action {
            let error = AgentLifecycleError.blockedByHook(reason: reason)
            agent._status = .error(error)
            throw error
        }
    }

    telemetry?.emit(TelemetryEvent(kind: .agentStarted(goal: goal)))
    let startTime = ContinuousClock.now

    // 3. Execute with cancellation support
    let result: String
    do {
        result = try await withTaskCancellationHandler {
            try await agent.execute(goal: goal)
        } onCancel: {
            // Agents should check Task.isCancelled at natural suspension points
            // within their execute() method. The tool loop checks automatically
            // via Task.checkCancellation() at each iteration.
        }
    } catch is CancellationError {
        agent._status = .paused
        if let hooks {
            await hooks.fire(.agentCancelled)
        }
        telemetry?.emit(TelemetryEvent(kind: .agentFailed(error: CancellationError())))
        // Auto-save paused session
        if let store = sessionStore {
            let session = AgentSession(
                agentType: sessionAgentType ?? String(describing: type(of: agent)),
                goal: goal,
                transcriptEntries: agent._transcript.entries.map { CodableTranscriptEntry(from: $0) },
                completedStepIndex: agent._transcript.entries.count - 1
            )
            try? await store.save(session)
            if let hooks {
                await hooks.fire(.sessionSaved(sessionId: session.sessionId))
            }
        }
        throw CancellationError()
    } catch {
        agent._status = .error(error)
        if let hooks {
            await hooks.fire(.agentFailed(error: error))
        }
        telemetry?.emit(TelemetryEvent(kind: .agentFailed(error: error)))
        // Auto-save failed session
        if let store = sessionStore {
            let session = AgentSession(
                agentType: sessionAgentType ?? String(describing: type(of: agent)),
                goal: goal,
                transcriptEntries: agent._transcript.entries.map { CodableTranscriptEntry(from: $0) },
                completedStepIndex: agent._transcript.entries.count - 1
            )
            try? await store.save(session)
        }
        throw error
    }

    // 4. Complete
    let duration = ContinuousClock.now - startTime
    agent._status = .completed(result)

    if let hooks {
        await hooks.fire(.agentCompleted(result: result))
    }
    telemetry?.emit(TelemetryEvent(kind: .agentCompleted(result: result, duration: duration)))

    // Auto-save completed session
    if let store = sessionStore {
        let session = AgentSession(
            agentType: sessionAgentType ?? String(describing: type(of: agent)),
            goal: goal,
            transcriptEntries: agent._transcript.entries.map { CodableTranscriptEntry(from: $0) },
            completedStepIndex: agent._transcript.entries.count - 1
        )
        try? await store.save(session)
        if let hooks {
            await hooks.fire(.sessionSaved(sessionId: session.sessionId))
        }
    }

    return result
}
