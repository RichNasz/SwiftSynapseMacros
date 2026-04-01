# Integration Guide

How SwiftSynapseMacros bridges the SwiftSynapse ecosystem into a cohesive agent platform.

## Overview

SwiftSynapseMacros sits at the top of the SwiftSynapse ecosystem, combining multiple sibling packages into a production-grade agent orchestration layer. Understanding how the packages relate helps you use the framework effectively.

## Package Relationships

```
SwiftSynapseMacros (agent harness + macros + UI)
    |
    +-- SwiftOpenResponsesDSL   (LLM client, responses, transcript entries)
    |
    +-- SwiftLLMToolMacros      (tool definitions, JSON schemas, @LLMTool)
    |
    +-- SwiftOpenSkills          (agentskills.io standard, skill discovery)
```

- **SwiftOpenResponsesDSL** provides `Agent` (the actor that handles LLM communication and tool dispatch), `LLMClient`, `TranscriptEntry`, and response types.
- **SwiftLLMToolMacros** provides `@LLMTool` and `@LLMToolArguments` macros for generating tool definitions and JSON schemas, plus `FunctionToolParam` and protocol types.
- **SwiftOpenSkills** provides `SkillStore`, `SkillsAgent`, and skill discovery for the agentskills.io standard.
- **SwiftSynapseMacros** bridges these into a complete agent harness with macros, lifecycle management, typed tools, hooks, permissions, recovery, and production capabilities.

## How Re-Exports Work

The client target (`SwiftSynapseMacrosClient`) uses `@_exported import` for all sibling packages:

```swift
@_exported import SwiftLLMToolMacros
@_exported import SwiftOpenResponsesDSL
@_exported import SwiftOpenSkills
```

A single `import SwiftSynapseMacrosClient` gives you access to all types from all packages.

## Architecture Layers

### Layer 1: Macros

The four macros (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`) generate boilerplate. `@SpecDrivenAgent` is the primary macro — it generates `run(goal:)` which calls `agentRun()` for lifecycle orchestration.

### Layer 2: Agent Harness

The harness provides the runtime between `run(goal:)` and your `execute(goal:)`:

| Component | Purpose |
|-----------|---------|
| `AgentToolProtocol` / `ToolRegistry` | Typed, self-describing tools with batch dispatch |
| `AgentToolLoop` | Reusable tool dispatch loop (sync and streaming) |
| `AgentHookPipeline` | 15 event types with block/modify/proceed semantics |
| `PermissionGate` | Policy-driven tool access control |
| `AgentLLMClient` | Backend abstraction (cloud, on-device, hybrid) |
| `RecoveryChain` | Self-healing from context overflow and truncation |
| `ContextBudget` | Token budget tracking and compaction |
| `SubagentRunner` | Child agent execution with lifecycle modes |

### Layer 3: Production Capabilities

Opt-in modules that integrate through established extension points:

| Capability | Extension Point |
|------------|----------------|
| Session Persistence | `agentRun()` parameter |
| Guardrails | `AgentToolLoop` parameter |
| Tool Progress | `ToolRegistry.dispatch()` parameter |
| MCP Integration | `ToolRegistry.register()` |
| Context Compression | `AgentToolLoop` parameter |
| Configuration Hierarchy | `AgentConfiguration` resolution |
| Caching | `ToolRegistry` dispatch path |
| Denial Tracking | `PermissionGate` wrapper |
| Multi-Agent Coordination | `SubagentRunner` orchestration |
| Plugin System | Hooks + tools + guardrails registration |

### Layer 4: SwiftUI

`SwiftSynapseUI` provides drop-in views that bind to `ObservableTranscript` and `AgentStatus`:

- `AgentChatView` — complete chat interface
- `TranscriptView` — chat-style message list
- `AgentStatusView` — status indicator
- `StreamingTextView` — real-time streaming with cursor
- `ToolCallDetailView` — expandable tool call details
- `AgentAppIntent` — Siri Shortcuts integration

## Type Flow

A typical agent request flows through these types:

```
AgentConfiguration
    → AgentLLMClient (CloudLLMClient or HybridLLMClient)
        → AgentRequest (model, prompt, tools, system prompt)
            → AgentResponse (text, tool calls, token counts)
                → ToolRegistry.dispatch() → ToolResult
                    → TranscriptEntry → ObservableTranscript
```

Hooks fire at each transition point. Guardrails check before tool dispatch and after LLM response. The context budget tracks token usage and triggers compaction when needed.

## LLM Backend Selection

`AgentConfiguration.buildClient()` selects the backend based on `executionMode`:

| Mode | Backend | When to use |
|------|---------|-------------|
| `.cloud` | `CloudLLMClient` | Any OpenAI-compatible API endpoint |
| `.onDevice` | Foundation Models | iOS 26+ / macOS 26+ with Apple Intelligence |
| `.hybrid` | `HybridLLMClient` | On-device first, cloud fallback |

## Macro Target Isolation

The compiler plugin target (`SwiftSynapseMacros`) can only import SwiftSyntax. It generates code as strings that reference types (`AgentStatus`, `ObservableTranscript`, etc.) resolved at the call site where `SwiftSynapseMacrosClient` is imported.

## Combining Everything

A production agent might use macros, harness, and production capabilities together:

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
actor ProductionAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()

        // Tools with progress reporting
        let tools = ToolRegistry()
        tools.register(DataImportTool())
        tools.register(AnalysisTool())

        // Permissions
        let gate = PermissionGate()
        await gate.addPolicy(ToolListPolicy(rules: [
            .requireApproval(["dataImport"]),
        ]))
        tools.permissionGate = gate

        // Hooks
        let hooks = AgentHookPipeline()
        await hooks.add(AuditLoggingHook())

        // Guardrails
        let guardrails = GuardrailPipeline()
        await guardrails.add(ContentFilter.default)

        // Recovery
        let recovery = RecoveryChain.default

        return try await AgentToolLoop.run(
            client: client, config: config, goal: goal,
            tools: tools, transcript: _transcript,
            hooks: hooks, guardrails: guardrails,
            recovery: recovery,
            compactionTrigger: .threshold(0.75)
        )
    }
}
```
