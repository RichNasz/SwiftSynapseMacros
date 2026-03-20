import SwiftLLMToolMacros

public struct AgentTool: Sendable {
    public let definition: ToolDefinition

    public init(definition: ToolDefinition) {
        self.definition = definition
    }

    public init<T: LLMTool>(_ tool: T.Type) {
        self.definition = T.toolDefinition
    }
}
