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

Production-grade agent harness for Swift — macros, tools, hooks, permissions, streaming, recovery, MCP, multi-agent coordination, and everything between your `execute(goal:)` and a deployed agent.

## Overview

SwiftSynapseMacros is the orchestration layer for the [SwiftSynapse](https://github.com/RichNasz/SwiftSynapse) ecosystem. It provides:

- **Swift macros** that generate agent scaffolding (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`)
- **A complete agent harness** with typed tools, lifecycle management, streaming, hooks, permissions, recovery, telemetry, and context management
- **Production capabilities** including session persistence, guardrails, MCP integration, multi-agent coordination, caching, and a plugin system
- **SwiftUI components** via `SwiftSynapseUI` for drop-in agent interfaces

### How It Works

You write `execute(goal:)` with your domain logic. The `@SpecDrivenAgent` macro generates `run(goal:)`, which calls `agentRun()` to handle status transitions, transcript management, error handling, cancellation, hooks, and telemetry. The harness provides typed tools, permissions, recovery strategies, and context budget tracking.

```swift
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

### Guides
- <doc:AgentHarnessGuide>
- <doc:ProductionGuide>

### Macros
- ``SpecDrivenAgent()``
- ``StructuredOutput()``
- ``Capability()``
- ``AgentGoal()``

### Agent Lifecycle
- ``AgentExecutable``
- ``AgentStatus``
- ``ObservableTranscript``

### Tool System
- ``AgentToolProtocol``
- ``ToolRegistry``
- ``AgentToolLoop``

### LLM Backends
- ``AgentLLMClient``
- ``AgentConfiguration``

### Hooks and Permissions
- ``AgentHookPipeline``
- ``PermissionGate``

### Recovery and Context
- ``RecoveryChain``
- ``ContextBudget``
- ``TranscriptCompressor``

### Production Capabilities
- ``SessionStore``
- ``GuardrailPipeline``
- ``MCPManager``
- ``CoordinationRunner``
- ``PluginManager``

### Telemetry
- ``TelemetrySink``
- ``TelemetryEvent``
