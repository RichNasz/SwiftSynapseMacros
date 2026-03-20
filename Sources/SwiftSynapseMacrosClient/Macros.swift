// Generated strictly from CodeGenSpecs/Overview.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
@_exported import SwiftLLMToolMacros
@_exported import SwiftResponsesDSL

/// Generates an agent scaffold with status tracking, LLMClient wrapper, transcript, and run loop.
/// Attach to an `actor` declaration.
@attached(member, names: named(Status), named(_status), named(_transcript), named(_dslAgent), named(status), named(isRunning), named(transcript), named(client), named(run))
public macro SpecDrivenAgent() = #externalMacro(module: "SwiftSynapseMacros", type: "SpecDrivenAgentMacro")

/// Generates a `textFormat` property bridging `@LLMToolArguments`' `jsonSchema` to `TextFormat`.
/// Attach to a `struct` declaration.
@attached(member, names: named(textFormat))
public macro StructuredOutput() = #externalMacro(module: "SwiftSynapseMacros", type: "StructuredOutputMacro")

/// Generates an `agentTools()` method bridging `@LLMTool` types to `AgentTool`.
/// Attach to a `struct` or `class` declaration.
@attached(member, names: named(agentTools))
public macro Capability() = #externalMacro(module: "SwiftSynapseMacros", type: "CapabilityMacro")
