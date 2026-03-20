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

Attach to an `actor` to generate status tracking, transcript, LLM client wrapper, and a `run(_:)` method.

```swift
@SpecDrivenAgent
actor MyAgent {
    // Generated: Status enum, _status, _transcript, _dslAgent,
    //            status, isRunning, transcript, client, run(_:)
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

## Client Types

| Type | Description |
|------|-------------|
| `TranscriptEntry` | Role + content wrapper for conversation history |
| `AgentTool` | Bridges `ToolDefinition` / `LLMTool` types |
| `TextFormat` | `.jsonSchema` or `.text` output format |
| `SwiftSynapseError` | Error cases for agent orchestration |
| `ObservableTranscript` | `@Observable` class for SwiftUI transcript binding |

## Dependencies

| Package | Purpose |
|---------|---------|
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | LLM client, response types, roles |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Tool definitions, JSON schema, `@LLMTool` macro |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation infrastructure |
