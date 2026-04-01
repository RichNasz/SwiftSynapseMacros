# Getting Started

Build your first agent with SwiftSynapseMacros — from a simple LLM call to a tool-using agent with hooks and permissions.

## Overview

SwiftSynapseMacros lets you create production-ready LLM agents with minimal boilerplate. The `@SpecDrivenAgent` macro generates lifecycle scaffolding; you write only `execute(goal:)` with your domain logic.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Installation

Add SwiftSynapseMacros to your `Package.swift`:

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
            ]
        ),
    ]
)
```

Importing `SwiftSynapseMacrosClient` also gives you access to SwiftOpenResponsesDSL, SwiftLLMToolMacros, and SwiftOpenSkills types via re-exports.

For SwiftUI views, also add `SwiftSynapseUI`.

## Step 1: Create a Minimal Agent

Annotate an `actor` with `@SpecDrivenAgent` and implement `execute(goal:)`:

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
actor SimpleAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let agent = Agent(client: client, model: config.modelName)
        return try await agent.send(goal)
    }
}
```

The macro generates `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`, and `AgentExecutable` conformance. The generated `run(goal:)` calls `agentRun()`, which handles status transitions, transcript reset, error handling, and cancellation — then delegates to your `execute(goal:)`.

## Step 2: Configure and Run

```swift
let config = try AgentConfiguration.fromEnvironment()
let agent = try SimpleAgent(configuration: config)
let reply = try await agent.run(goal: "What is quantum computing?")
print(reply)
```

`AgentConfiguration.fromEnvironment()` reads `SWIFTSYNAPSE_SERVER_URL`, `SWIFTSYNAPSE_MODEL`, and `SWIFTSYNAPSE_API_KEY` from environment variables.

## Step 3: Add Tools

Create typed tools by conforming to `AgentToolProtocol`, register them in a `ToolRegistry`, and use `AgentToolLoop.run()`:

```swift
struct CalculateTool: AgentToolProtocol {
    struct Input: Codable, Sendable { let expression: String }
    typealias Output = String

    static let name = "calculate"
    static let description = "Evaluates a math expression"
    static let isConcurrencySafe = true
    static var inputSchema: FunctionToolParam { /* ... */ }

    func execute(input: Input) async throws -> String {
        // evaluation logic
    }
}

@SpecDrivenAgent
actor MathAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let tools = ToolRegistry()
        tools.register(CalculateTool())

        return try await AgentToolLoop.run(
            client: client, config: config, goal: goal,
            tools: tools, transcript: _transcript
        )
    }
}
```

Tools marked `isConcurrencySafe = true` run in parallel via `TaskGroup` during batch dispatch.

## Step 4: Add Hooks

Intercept agent and tool events without modifying agent code:

```swift
let hooks = AgentHookPipeline()
let loggingHook = ClosureHook(on: [.preToolUse, .postToolUse]) { event in
    switch event {
    case .preToolUse(let calls):
        print("Calling tools: \(calls.map(\.name))")
    case .postToolUse(let results):
        for r in results { print("Tool \(r.name): \(r.success ? "OK" : "FAIL")") }
    default: break
    }
    return .proceed
}
await hooks.add(loggingHook)

// Pass hooks to AgentToolLoop
return try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: _transcript, hooks: hooks
)
```

## Step 5: Observe in SwiftUI

`ObservableTranscript` is `@Observable` — bind it directly to SwiftUI views:

```swift
import SwiftSynapseUI

struct AgentView: View {
    let agent: some ObservableAgent

    var body: some View {
        AgentChatView(agent: agent)
    }
}
```

Or build custom views using the agent's `status` and `transcript` properties.

## Next Steps

- Read the <doc:MacroReference> for details on all four macros
- See the <doc:IntegrationGuide> to understand how the packages work together
- Explore the <doc:AgentHarnessGuide> for tools, hooks, permissions, and recovery
- Read the <doc:ProductionGuide> for session persistence, guardrails, MCP, and more
