<!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->

# SwiftSynapseMacros

Swift macros and core types for AI agent orchestration. Part of the [SwiftSynapse](https://github.com/RichNasz/SwiftSynapse) ecosystem.

## Overview

SwiftSynapseMacros provides:

- **Swift macros** that generate agent scaffolding (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`)
- **Core types** used by macro-generated code and SwiftUI views (`AgentStatus`, `ObservableTranscript`, `AgentExecutable`, `ToolProgressUpdate`)
- **SwiftUI views** via `SwiftSynapseUI` for drop-in agent interfaces

For the full agent harness (tool loop, hooks, permissions, streaming, recovery, MCP, multi-agent coordination, and production capabilities), see [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness).

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
]
```

Add `"SwiftSynapseMacrosClient"` to your target's dependencies for macros and core types. Add `"SwiftSynapseUI"` for SwiftUI views.

Most agent projects should depend on [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) instead, which re-exports this package.

## Macros

### @SpecDrivenAgent

Generates lifecycle scaffolding on `actor` declarations: `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`, and `AgentExecutable` conformance. The generated `run(goal:)` calls `agentRun()` (from `SwiftSynapseHarness`) which handles status transitions, transcript reset, error/completion, cancellation, hooks, and telemetry.

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
actor MyAgent {
    func execute(goal: String) async throws -> String {
        // Your domain logic here
    }
}
```

### @StructuredOutput

Generates a `textFormat` property on structs for JSON schema output formatting.

### @Capability

Generates an `agentTools()` method bridging `@LLMTool` types to `AgentToolDefinition`.

### @AgentGoal

Validates prompt strings at compile time and generates `AgentGoalMetadata` with configurable parameters (maxTurns, temperature, requiresTools, preferredFormat).

## Core Types

| Type | Purpose |
|------|---------|
| `AgentStatus` | Agent lifecycle state (idle, running, paused, error, completed) |
| `ObservableTranscript` | `@Observable` transcript for SwiftUI binding |
| `AgentExecutable` | Protocol for `@SpecDrivenAgent` actors |
| `AgentLifecycleError` | Lifecycle errors (emptyGoal, blockedByHook) |
| `ToolProgressUpdate` | Progress updates from tool execution |
| `TextFormat` | Output format enum (jsonSchema, text) |
| `AgentGoalMetadata` | Compile-time validated goal parameters |

## SwiftUI Integration

`SwiftSynapseUI` provides drop-in views:

- `AgentChatView` — Complete chat interface with status, transcript, and input
- `AgentStatusView` — Status indicator with icons and animations
- `TranscriptView` — Chat-style message list with tool call details
- `StreamingTextView` — Real-time streaming text with cursor animation
- `ToolCallDetailView` — Expandable tool call arguments and results
- `AgentAppIntent` — Expose agents as Siri Shortcuts

## Dependencies

| Package | Purpose |
|---------|---------|
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | LLM client, response types, transcript entries |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Tool definitions, JSON schema, `@LLMTool` macro |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation infrastructure |

## Spec-Driven Development

All `.swift` files are generated from specs in `CodeGenSpecs/`. To change behavior: edit the spec, regenerate, never edit generated files directly. See [CodeGenSpecs/Overview.md](CodeGenSpecs/Overview.md).
