// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import AppIntents
import SwiftSynapseMacrosClient

/// Base protocol for agent-backed App Intents.
///
/// Conform to this protocol and provide an agent factory to expose
/// any `ObservableAgent` as a Siri Shortcut or Shortcuts action.
///
/// ```swift
/// struct AskAgentIntent: AgentAppIntent {
///     static var title: LocalizedStringResource = "Ask Agent"
///     static var description = IntentDescription("Run an AI agent with a goal")
///
///     @Parameter(title: "Goal") var goal: String
///
///     func createAgent() throws -> MyAgent {
///         let config = try AgentConfiguration.fromEnvironment()
///         return try MyAgent(configuration: config)
///     }
/// }
/// ```
public protocol AgentAppIntent: AppIntent where Self: Sendable {
    associatedtype AgentType: ObservableAgent

    /// The goal to send to the agent.
    var goal: String { get }

    /// Creates and configures the agent instance.
    func createAgent() throws -> AgentType
}

extension AgentAppIntent {
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let agent = try createAgent()
        let result = try await agent.execute(goal: goal)
        return .result(value: result)
    }
}
