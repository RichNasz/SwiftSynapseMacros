# ``SwiftSynapseMacrosClient``

@Metadata {
    @DisplayName("SwiftSynapseMacros")
    @PageKind(sampleCode)
    @CallToAction(
        purpose: link,
        label: "View on GitHub",
        url: "https://github.com/RichNasz/SwiftSynapseMacros"
    )
}

Swift macros and core types for AI agent orchestration.

## Overview

SwiftSynapseMacros provides the foundational layer for the [SwiftSynapse](https://github.com/RichNasz/SwiftSynapse) ecosystem:

- **Swift macros** that generate agent scaffolding (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`)
- **Core types** used by macro-generated code (`AgentStatus`, `ObservableTranscript`, `AgentExecutable`, `ToolProgressUpdate`)
- **SwiftUI components** via `SwiftSynapseUI` for drop-in agent interfaces

For the full agent harness (tool loop, hooks, permissions, streaming, recovery, MCP, multi-agent coordination), see [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness).

### How It Works

You write `execute(goal:)` with your domain logic. The `@SpecDrivenAgent` macro generates `run(goal:)`, which calls `agentRun()` (from `SwiftSynapseHarness`) to handle status transitions, transcript management, error handling, cancellation, hooks, and telemetry.

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
actor CustomerSupportAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let tools = ToolRegistry()
        tools.register(LookupOrderTool())
        tools.register(RefundTool())

        return try await AgentToolLoop.run(
            client: client, config: config, goal: goal,
            tools: tools, transcript: _transcript
        )
    }
}
```

## Topics

### Essentials
- <doc:GettingStarted>
- <doc:MacroReference>
- <doc:IntegrationGuide>

### Macros
- ``SpecDrivenAgent()``
- ``StructuredOutput()``
- ``Capability()``
- ``AgentGoal()``

### Core Types
- ``AgentExecutable``
- ``AgentStatus``
- ``ObservableTranscript``
- ``AgentGoalMetadata``
- ``ToolProgressUpdate``
- ``TextFormat``
