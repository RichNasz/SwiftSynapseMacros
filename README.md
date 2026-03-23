<!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->

# SwiftSynapseMacros

Macro-powered orchestration layer for SwiftSynapse agents.

## Overview

SwiftSynapseMacros provides Swift macros that generate boilerplate for LLM agent orchestration. It bridges SwiftOpenResponsesDSL's LLM client and SwiftLLMToolMacros' tool definitions into observable, status-tracked agent actors.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
]
```

Then add `"SwiftSynapseMacrosClient"` to your target's dependencies.

## Macros

### @SpecDrivenAgent

Attach to an `actor` to generate status tracking, transcript, LLM client wrapper, and a `run(goal:)` method that delegates to `AgentRuntime`.

```swift
@SpecDrivenAgent
actor MyAgent {
    // Generated: _status, _transcript, _client,
    //            status, transcript, client,
    //            configure(client:), run(goal:)
}
```

### @StructuredOutput

Attach to a `struct` (with `@LLMToolArguments` conformance) to generate a `textFormat` property.

```swift
@StructuredOutput
struct MyResponse {
    // Generated: static var textFormat: TextFormat
}
```

### @Capability

Attach to a `struct` or `class` to generate an `agentTools()` method bridging `@LLMTool` types.

```swift
@Capability
struct MyTools {
    // Generated: func agentTools() -> [AgentTool]
}
```

### @AgentGoal

Attach to a `static let` string to validate the prompt at compile time and generate an `AgentGoalMetadata` companion constant.

```swift
@AgentGoal(maxTurns: 15, temperature: 0.4)
static let researchGoal = """
You are a research assistant. Think step-by-step. Use tools when needed.
"""
// Generated: static let researchGoal_metadata: AgentGoalMetadata
```

Compile-time validation includes: empty prompt errors, parameter range checks, and warnings for prompts missing agentic keywords.

## Using Macros Together

The macros are designed to work in combination:

```swift
// 1. Define tools with @Capability
@Capability
struct ResearchTools {
    // Bridges @LLMTool types to AgentTool
}

// 2. Define structured output with @StructuredOutput
@StructuredOutput
struct ResearchResult {
    // Bridges @LLMToolArguments JSON schema to TextFormat
}

// 3. Define validated goals with @AgentGoal
@AgentGoal(maxTurns: 20, requiresTools: true)
static let researchGoal = """
You are a research assistant. Think step-by-step. Use tools when needed.
Output FINAL ANSWER when done.
"""

// 4. Orchestrate with @SpecDrivenAgent
@SpecDrivenAgent
actor ResearchAgent {
    // Generated: status tracking, transcript, client, run(goal:)
    // Uses AgentRuntime to execute the dynamic reasoning loop
}
```

## Client Types

| Type | Description |
|------|-------------|
| `TranscriptEntry` | Role + content wrapper for conversation history |
| `AgentTool` | Bridges `ToolDefinition` / `LLMTool` types |
| `TextFormat` | `.jsonSchema` or `.text` output format |
| `SwiftSynapseError` | Error cases for agent orchestration |
| `ObservableTranscript` | `@Observable` class for SwiftUI transcript binding |
| `AgentStatus` | Shared status enum (`idle`, `running`, `paused`, `error`, `completed`) |
| `AgentRuntime` | Runtime engine for dynamic agent reasoning loops |
| `AgentGoalMetadata` | Compile-time metadata for validated agent goals |

## Dependencies

| Package | Purpose |
|---------|---------|
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | LLM client, response types, roles |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Tool definitions, JSON schema, `@LLMTool` macro |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation infrastructure |
