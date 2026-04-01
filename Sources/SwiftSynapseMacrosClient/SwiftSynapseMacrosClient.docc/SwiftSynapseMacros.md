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
For the full agent runtime — tool loop, hooks, permissions, streaming, recovery, MCP, multi-agent coordination, and SwiftUI views — see [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness).

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

### Macro Reference
- <doc:SpecDrivenAgent>
- <doc:Capability>
- <doc:StructuredOutput>
- <doc:AgentGoal>

### How-To Guides
- <doc:HowTo-SpecDrivenAgent>
- <doc:HowTo-Capability>
- <doc:HowTo-StructuredOutput>
- <doc:HowTo-AgentGoal>
- <doc:HowTo-CombiningMacros>

### Core Types
- ``AgentExecutable``
- ``AgentStatus``
- ``ObservableTranscript``
- ``AgentGoalMetadata``
- ``ToolProgressUpdate``
- ``TextFormat``
