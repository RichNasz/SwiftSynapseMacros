# Integration Guide

How SwiftSynapseMacros bridges SwiftResponsesDSL and SwiftLLMToolMacros.

## Overview

SwiftSynapseMacros sits at the top of the SwiftSynapse ecosystem, combining two sibling packages into a cohesive agent orchestration layer. Understanding how the packages relate helps you use the macros effectively.

## Package Relationships

```
SwiftSynapseMacros
    |
    +-- SwiftResponsesDSL      (LLM client, responses, roles)
    |
    +-- SwiftLLMToolMacros     (tool definitions, JSON schemas)
```

- **SwiftResponsesDSL** provides `LLMClient` (the actor that communicates with LLM APIs), `Response`, `Role`, and message types.
- **SwiftLLMToolMacros** provides `@LLMTool` and `@LLMToolArguments` macros for generating tool definitions and JSON schemas, plus `ToolDefinition`, `JSONSchemaValue`, and protocol types.
- **SwiftSynapseMacros** bridges these into agent-level abstractions with `@SpecDrivenAgent`, `@StructuredOutput`, and `@Capability`.

## How Re-Exports Work

The client target (`SwiftSynapseMacrosClient`) uses `@_exported import` for both sibling packages:

```swift
@_exported import SwiftLLMToolMacros
@_exported import SwiftResponsesDSL
```

This means importing `SwiftSynapseMacrosClient` gives you access to all types from all three packages. You don't need separate import statements.

## Type Bridging

### LLMClient to Agent

`@SpecDrivenAgent` generates a `client: LLMClient?` property. The `LLMClient` type comes from SwiftResponsesDSL. Inject it before calling `run(_:)`:

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
actor MyAgent { }

let agent = MyAgent()
agent.client = try LLMClient(
    baseURLString: "https://api.openai.com/v1/responses",
    apiKey: apiKey
)
```

### ToolDefinition to AgentTool

`AgentTool` wraps `ToolDefinition` from SwiftLLMToolMacros. Use `@Capability` to generate `agentTools()` methods that return `[AgentTool]`:

```swift
@LLMTool
struct WebSearchTool: LLMTool {
    // @LLMTool generates toolDefinition
}

@Capability
struct SearchCapability {
    // agentTools() bridges LLMTool types to [AgentTool]
}
```

### JSONSchemaValue to TextFormat

`@StructuredOutput` bridges `Self.jsonSchema` (a `JSONSchemaValue` from `@LLMToolArguments`) to the `TextFormat` enum used by the orchestration layer:

```swift
@LLMToolArguments
@StructuredOutput
struct AnalysisResult {
    let summary: String
    let confidence: Double
    // @LLMToolArguments generates jsonSchema
    // @StructuredOutput generates textFormat using that schema
}
```

## Architecture Constraints

### Macro Target Isolation

The compiler plugin target (`SwiftSynapseMacros`) can only import SwiftSyntax. It cannot import sibling packages or the client target. The macro implementations generate code as strings that reference types (`TranscriptEntry`, `LLMClient`, etc.) which are resolved at the call site where `SwiftSynapseMacrosClient` is imported.

### Actor Enforcement

`@SpecDrivenAgent` is restricted to `actor` declarations because agents manage mutable state (`_status`, `_transcript`) and perform async network calls. Swift actors provide the necessary concurrency safety guarantees.

## Combining All Three Macros

A complete agent setup might use all three packages together:

```swift
import SwiftSynapseMacrosClient

// Tool definition (from SwiftLLMToolMacros)
@LLMTool
struct Calculator: LLMTool {
    static let toolDefinition = ToolDefinition(
        name: "calculate",
        description: "Perform math"
    )
}

// Structured output (bridges LLMToolMacros schema to TextFormat)
@LLMToolArguments
@StructuredOutput
struct MathResult {
    let answer: Double
    let explanation: String
}

// Capability (bridges tools to AgentTool)
@Capability
struct MathCapability { }

// Agent (orchestrates everything)
@SpecDrivenAgent
actor MathAgent { }
```
