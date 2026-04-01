// Generated strictly from CodeGenSpecs/Client-Types.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftLLMToolMacros

@available(*, deprecated, message: "Use AgentToolProtocol instead for typed tool definitions with automatic dispatch")
public struct AgentToolDefinition: Sendable {
    public let definition: ToolDefinition

    public init(definition: ToolDefinition) {
        self.definition = definition
    }

    public init<T: LLMTool>(_ tool: T.Type) {
        self.definition = T.toolDefinition
    }
}
