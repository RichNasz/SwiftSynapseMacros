// Generated strictly from CodeGenSpecs/Overview.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
@_exported import SwiftLLMToolMacros
@_exported import SwiftOpenResponsesDSL

/// Generates an agent scaffold with status tracking, LLMClient wrapper, transcript, and runtime loop.
/// Attach to an `actor` declaration.
@attached(member, names: named(_status), named(_transcript), named(status), named(transcript))
public macro SpecDrivenAgent() = #externalMacro(module: "SwiftSynapseMacros", type: "SpecDrivenAgentMacro")

/// Generates a `textFormat` property bridging `@LLMToolArguments`' `jsonSchema` to `TextFormat`.
/// Attach to a `struct` declaration.
@attached(member, names: named(textFormat))
public macro StructuredOutput() = #externalMacro(module: "SwiftSynapseMacros", type: "StructuredOutputMacro")

/// Generates an `agentTools()` method bridging `@LLMTool` types to `AgentTool`.
/// Attach to a `struct` or `class` declaration.
@attached(member, names: named(agentTools))
public macro Capability() = #externalMacro(module: "SwiftSynapseMacros", type: "CapabilityMacro")

/// Validates an agent goal prompt at compile time and generates an `AgentGoalMetadata` companion constant.
/// Attach to a `static let` string literal declaration.
@attached(peer, names: arbitrary)
public macro AgentGoal(
    maxTurns: Int = 20,
    temperature: Double = 0.7,
    requiresTools: Bool = false,
    preferredFormat: TextFormat = .text
) = #externalMacro(module: "SwiftSynapseMacros", type: "AgentGoalMacro")
