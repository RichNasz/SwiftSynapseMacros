// Generated from CodeGenSpecs/Shared-Session-Resume.md — Do not edit manually. Update spec and re-generate.

import Foundation

/// A codable snapshot of agent state for session persistence and resume.
///
/// Agents create `AgentSession` values via `currentSession()`.
/// Persistence (disk, iCloud, etc.) is the caller's responsibility.
public struct AgentSession: Codable, Sendable {
    /// Unique identifier for this session.
    public let sessionId: String

    /// The Swift type name of the actor (e.g., "LLMChat").
    public let agentType: String

    /// The original goal string passed to execute().
    public let goal: String

    /// The transcript at the time of interruption.
    public let transcriptEntries: [CodableTranscriptEntry]

    /// Index of the last successfully completed step.
    public let completedStepIndex: Int

    /// Optional agent-specific serialized state.
    public let customState: Data?

    /// Wall-clock time when the session was created.
    public let createdAt: Date

    /// Wall-clock time when the session was last saved.
    public let savedAt: Date

    public init(
        sessionId: String = UUID().uuidString,
        agentType: String,
        goal: String,
        transcriptEntries: [CodableTranscriptEntry],
        completedStepIndex: Int,
        customState: Data? = nil,
        createdAt: Date = Date(),
        savedAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.agentType = agentType
        self.goal = goal
        self.transcriptEntries = transcriptEntries
        self.completedStepIndex = completedStepIndex
        self.customState = customState
        self.createdAt = createdAt
        self.savedAt = savedAt
    }
}

/// A codable mirror of `TranscriptEntry` for session persistence.
///
/// `TranscriptEntry` (from SwiftOpenResponsesDSL) may not be `Codable`.
/// This type bridges the gap, converting to/from `TranscriptEntry`.
public enum CodableTranscriptEntry: Codable, Sendable {
    case userMessage(String)
    case assistantMessage(String)
    case toolCall(name: String, arguments: String)
    case toolResult(name: String, result: String)
    case error(String)

    /// Converts from a `TranscriptEntry`.
    public init(from entry: TranscriptEntry) {
        switch entry {
        case .userMessage(let text):
            self = .userMessage(text)
        case .assistantMessage(let text):
            self = .assistantMessage(text)
        case .toolCall(let name, let args):
            self = .toolCall(name: name, arguments: args)
        case .toolResult(let name, let result, _):
            self = .toolResult(name: name, result: result)
        case .reasoning:
            self = .assistantMessage("[reasoning]")
        case .error(let msg):
            self = .error(msg)
        }
    }

    /// Converts to a `TranscriptEntry`.
    public func toTranscriptEntry() -> TranscriptEntry {
        switch self {
        case .userMessage(let text):
            return .userMessage(text)
        case .assistantMessage(let text):
            return .assistantMessage(text)
        case .toolCall(let name, let args):
            return .toolCall(name: name, arguments: args)
        case .toolResult(let name, let result):
            return .toolResult(name: name, result: result, duration: .zero)
        case .error(let msg):
            return .error(msg)
        }
    }
}
