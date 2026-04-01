<!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->

# SwiftSynapseMacros

Swift macros and core types for AI agent scaffolding. Part of the [SwiftSynapse](https://github.com/RichNasz/SwiftSynapse) ecosystem.

## Overview

SwiftSynapseMacros provides:

- **Swift macros** that generate agent scaffolding at compile time (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`)
- **Core types** that macro-generated code and [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) depend on (`AgentStatus`, `ObservableTranscript`, `AgentExecutable`, `ToolProgressUpdate`)

For the full agent runtime — tool loop, hooks, permissions, streaming, recovery, MCP, multi-agent coordination, and SwiftUI views — see [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness).

## Documentation

The full documentation is available as DocC via two paths:

**[Browse on GitHub Pages](https://richnasz.github.io/SwiftSynapseMacros/documentation/swiftsynapsemacrosclient/)** — no Xcode required. Deployed automatically on push to `main`.

**Xcode Developer Documentation** — richest experience during development:

1. Open this project (or any project that depends on it) in Xcode.
2. Choose **Product > Build Documentation** (or open the Documentation window).
3. Navigate to **SwiftSynapseMacros** in the documentation navigator.

Both paths cover all macro reference pages, HowTo guides, and integration guides. The README covers installation and orientation only.

## Package Architecture

### Why this is a separate package

Swift's compiler plugin system has a hard constraint: `.macro()` targets can only depend on swift-syntax — they cannot import user-land packages. This means the macro plugin and its associated type declarations must live in an isolated package. **SwiftSynapseHarness depends on SwiftSynapseMacros, not the reverse.** The separation is a compiler requirement.

### The three-target structure

| Target | Kind | Purpose |
|--------|------|---------|
| `SwiftSynapseMacros` | `.macro` (compiler plugin) | Runs during `swift build`. Never imported at runtime. Constrained to SwiftSyntax only. |
| `SwiftSynapseMacrosClient` | `.target` (library) | The importable library. Activates the plugin via `#externalMacro` declarations, provides core types, and re-exports sibling packages. |
| `SwiftSynapseMacrosTests` | `.testTarget` | Validates that each macro expands to the correct source code (compile-time expansion snapshots, not runtime tests). |

Only `SwiftSynapseMacrosClient` is exported as a product. The `.macro` target is activated automatically when you depend on it.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Installation

### Building agents with `@SpecDrivenAgent` (most users)

Add **SwiftSynapseHarness**. It re-exports everything from this package via `@_exported import SwiftSynapseMacrosClient`, so a single import gives access to all macros, types, and the full agent runtime. SwiftSynapseMacros is fetched automatically as a transitive dependency.

```swift
// In Package.swift
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main")
```

```swift
// In your target dependencies
.product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness")
```

```swift
// In source files — one import covers everything
import SwiftSynapseHarness
```

### Using macros without the full harness (rare)

Only needed when you want the compile-time macros and core types but not the agent runtime.

```swift
// In Package.swift
.package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main")
// In your target dependencies: "SwiftSynapseMacrosClient"
```

### Extending the compiler plugin (contributors)

Work directly with this package. See `CodeGenSpecs/Macros-*.md` for the spec-driven contribution workflow.

## Macros

### @SpecDrivenAgent

Applied to `actor` declarations. Generates lifecycle scaffolding: `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`, and `AgentExecutable` conformance. The generated `run(goal:)` calls `agentRun()` from SwiftSynapseHarness, which handles status transitions, transcript reset, error handling, cancellation, hooks, and telemetry.

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

Applied to `struct` declarations. Generates a `textFormat` property that bridges the struct's JSON schema (from `@LLMToolArguments`) to `TextFormat`, enabling structured JSON responses from the LLM.

### @Capability

Applied to `struct` or `class` declarations. Generates an `agentTools()` method that bridges `@LLMTool`-annotated types to the agent's tool registry.

### @AgentGoal

A freestanding macro applied to string literals. Validates the prompt at compile time (non-empty, contains agentic keywords) and generates `AgentGoalMetadata` with configurable parameters.

```swift
let goal = #AgentGoal("Summarize the document", maxTurns: 5, temperature: 0.7)
```

## Using Macros Together

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
actor ResearchAgent {
    @Capability
    struct Tools {
        @LLMTool("search", description: "Search the web")
        func search(query: String) async throws -> String { ... }
    }

    func execute(goal: String) async throws -> String {
        let prompt = #AgentGoal("Research the topic and cite sources", requiresTools: true)
        return try await client.run(goal: prompt, tools: Tools().agentTools())
    }
}
```

## Core Types

| Type | Purpose |
|------|---------|
| `AgentStatus` | Agent lifecycle state: `.idle`, `.running`, `.paused`, `.error(Error)`, `.completed(Any)` |
| `ObservableTranscript` | `@Observable` transcript for SwiftUI binding; records all agent activity |
| `AgentExecutable` | Protocol that `@SpecDrivenAgent` actors conform to |
| `AgentLifecycleError` | Lifecycle errors: `.emptyGoal`, `.blockedByHook` |
| `ToolProgressUpdate` | Progress updates from tool execution |
| `TextFormat` | Output format: `.jsonSchema(name:schema:strict:)` or `.text` |
| `AgentGoalMetadata` | Compile-time validated goal parameters |

## Dependencies

| Package | Purpose |
|---------|---------|
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | LLM client, response types, transcript entries |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Tool definitions, JSON schema, `@LLMTool` macro |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation infrastructure |

## Spec-Driven Development

All `.swift` files are generated from specs in `CodeGenSpecs/`. To change behavior: edit the spec, regenerate, never edit generated files directly. See [CodeGenSpecs/Overview.md](CodeGenSpecs/Overview.md).
