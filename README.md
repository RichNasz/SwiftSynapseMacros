<!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->

# SwiftSynapseMacros

Production-grade agent harness for Swift. Macros, tools, hooks, permissions, streaming, recovery, MCP, multi-agent coordination — everything between your `execute(goal:)` and a deployed agent.

## Overview

SwiftSynapseMacros is the orchestration layer for the [SwiftSynapse](https://github.com/RichNasz/SwiftSynapse) ecosystem. It provides:

- **Swift macros** that generate agent scaffolding (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`)
- **A complete agent harness** with typed tools, lifecycle management, streaming, hooks, permissions, recovery, telemetry, and context management
- **Production capabilities** including session persistence, guardrails, MCP integration, multi-agent coordination, caching, and a plugin system

Designed for **business agents** — customer support, data processing, workflow automation — but general-purpose enough for any AI agent.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
]
```

Add `"SwiftSynapseMacrosClient"` to your target's dependencies. For SwiftUI views, also add `"SwiftSynapseUI"`.

## Quick Start

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
actor CustomerSupportAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    // This is all you write. The macro generates run(goal:),
    // status tracking, transcript management, and protocol conformance.
    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let tools = ToolRegistry()
        tools.register(LookupOrderTool())
        tools.register(RefundTool())

        return try await AgentToolLoop.run(
            client: client,
            config: config,
            goal: goal,
            tools: tools,
            transcript: _transcript
        )
    }
}
```

## Macros

### @SpecDrivenAgent

Generates lifecycle scaffolding on `actor` declarations: `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`, and `AgentExecutable` conformance. The generated `run(goal:)` calls `agentRun()` which handles status transitions, transcript reset, error/completion, cancellation, hooks, and telemetry.

```swift
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

## Agent Harness

The harness provides everything between `run(goal:)` and your `execute(goal:)`:

### Typed Tool System

```swift
struct CalculateTool: AgentToolProtocol {
    struct Input: Codable, Sendable { let expression: String }
    typealias Output = String

    static let name = "calculate"
    static let description = "Evaluates a math expression"
    static let isConcurrencySafe = true

    static var inputSchema: FunctionToolParam { /* ... */ }

    func execute(input: Input) async throws -> String {
        // Tool logic
    }
}

// Register and dispatch
let tools = ToolRegistry()
tools.register(CalculateTool())
let result = try await tools.dispatch(name: "calculate", callId: "1", arguments: json)
```

Tools marked `isConcurrencySafe` run in parallel via `TaskGroup` during batch dispatch.

### Hook System

Intercept agent and tool events without modifying agent code:

```swift
let auditHook = ClosureHook(on: [.preToolUse, .postToolUse]) { event in
    switch event {
    case .preToolUse(let calls):
        AuditLog.record("Tools invoked: \(calls.map(\.name))")
    case .postToolUse(let results):
        for r in results { AuditLog.record("Tool \(r.name): \(r.success ? "OK" : "FAIL")") }
    default: break
    }
    return .proceed  // or .block(reason:) or .modify(String)
}

let pipeline = AgentHookPipeline()
await pipeline.add(auditHook)
```

15 event types: agent lifecycle, tool use, LLM requests/responses, transcript updates, sessions, guardrails, coordination phases.

### Permission System

Policy-driven tool access control with human-in-the-loop approval:

```swift
let gate = PermissionGate()
await gate.addPolicy(ToolListPolicy(rules: [
    .requireApproval(["chargeCard", "sendEmail"]),
    .deny(["deleteAccount"])
]))
await gate.setApprovalDelegate(myDelegate)
```

### Recovery Strategies

Self-healing from context window exhaustion and output truncation:

- **ReactiveCompactionStrategy** — compresses transcript when context window exceeded
- **OutputTokenEscalationStrategy** — increases max tokens on truncation
- **ContinuationStrategy** — sends continuation prompt
- **RecoveryChain** — ordered chain, first success wins

### Streaming

`AgentToolLoop.runStreaming()` dispatches concurrency-safe tools as their definitions complete in the LLM stream. Text deltas forwarded to `ObservableTranscript` for real-time SwiftUI updates.

### LLM Backend Abstraction

Three backends behind one protocol:

- `CloudLLMClient` — wraps SwiftOpenResponsesDSL
- `HybridLLMClient` — Foundation Models on-device → cloud fallback
- `AgentConfiguration.buildClient()` selects based on `executionMode`

### Subagent Composition

```swift
let result = try await SubagentRunner.run(
    agentFactory: { try SummaryAgent(configuration: $0) },
    goal: "Summarize this document",
    context: SubagentContext(config: parentConfig, lifecycleMode: .shared)
)
```

`.shared` propagates parent cancellation; `.independent` runs in its own task.

## Production Capabilities

### Session Persistence

```swift
let store = FileSessionStore()
// agentRun() auto-saves on completion, error, or cancellation
try await agentRun(agent: myAgent, goal: "...", sessionStore: store)
// Later: resume
if let session = try await store.load(sessionId: savedId) {
    myAgent._transcript.restore(from: session.transcriptEntries)
}
```

### Guardrails

```swift
let guardrails = GuardrailPipeline()
await guardrails.add(ContentFilter.default) // PII, secrets, API keys

try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    guardrails: guardrails
)
// Blocks tool arguments containing credit card numbers, SSNs, etc.
// Sanitizes or blocks LLM output containing sensitive data
```

### Tool Progress

```swift
struct DataImportTool: ProgressReportingTool {
    func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output {
        for (i, batch) in batches.enumerated() {
            await progress.reportProgress(ToolProgressUpdate(
                callId: callId, toolName: Self.name,
                message: "Importing batch \(i+1)/\(batches.count)",
                fractionComplete: Double(i+1) / Double(batches.count)
            ))
            try await processBatch(batch)
        }
    }
}
```

### MCP Integration

Connect to Model Context Protocol servers — databases, CRMs, APIs:

```swift
let manager = MCPManager()
try await manager.addServer(MCPServerConfig(
    name: "database",
    command: "/usr/local/bin/mcp-postgres",
    arguments: ["--connection", connectionString]
))
try await manager.registerAll(in: tools) // MCP tools appear as native tools
```

### Advanced Compression

```swift
let compressor = CompositeCompressor.default
// Chain: MicroCompactor → ImportanceCompressor → SlidingWindowCompressor

try await AgentToolLoop.run(
    ..., compressor: compressor,
    compactionTrigger: .threshold(0.75) // Compress at 75% budget
)
```

### Configuration Hierarchy

7-level priority: CLI > local file > project file > user file > MDM policy > remote > environment.

```swift
let resolver = ConfigurationResolver()
await resolver.addSource(EnvironmentConfigSource())
await resolver.addSource(FileConfigSource.userDefault)
await resolver.addSource(MDMConfigSource()) // Enterprise MDM profiles
let config = try await resolver.resolveConfiguration()
```

### Caching

```swift
let cache = ToolResultCache(policy: CachePolicy(maxEntries: 50, ttl: .seconds(300)))
// Identical tool calls return cached results instantly
```

### Denial Tracking

```swift
let adaptiveGate = AdaptivePermissionGate(
    gate: baseGate,
    mode: .default,       // or .autoApprove, .alwaysPrompt, .planOnly
    denialThreshold: 3    // Switch behavior after 3 consecutive denials
)
```

### Multi-Agent Coordination

```swift
let phases = [
    CoordinationPhase(name: "research", goal: "Research the topic",
                      agentFactory: { try ResearchAgent(configuration: $0) }),
    CoordinationPhase(name: "synthesize", goal: "Synthesize findings",
                      dependencies: ["research"],
                      agentFactory: { try SynthesisAgent(configuration: $0) }),
]
let result = try await CoordinationRunner.run(phases: phases, config: config)
```

Phases with satisfied dependencies run in parallel. Results stored in `TeamMemory` for downstream phases.

### Plugin System

```swift
struct AuditPlugin: AgentPlugin {
    let name = "audit"
    let version = "1.0.0"

    func activate(context: PluginContext) async throws {
        await context.hookPipeline.add(AuditLoggingHook())
        await context.guardrailPipeline?.add(ComplianceFilter())
    }
    func deactivate() async {}
}

let plugins = PluginManager()
await plugins.register(AuditPlugin())
await plugins.activateAll(context: pluginContext)
```

## Telemetry

Structured event emission to any backend:

```swift
let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),          // Unified logging
    InMemoryTelemetrySink(),       // Testing
])
```

11 event types: agent lifecycle, LLM calls (model, tokens, duration), tool calls (name, duration, success), retries, budget exhaustion, guardrail triggers, context compaction, plugin lifecycle.

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
| [SwiftOpenSkills](https://github.com/RichNasz/SwiftOpenSkills) | Skills framework integration |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | Macro implementation infrastructure |

## Spec-Driven Development

All `.swift` files are generated from specs in `CodeGenSpecs/`. To change behavior: edit the spec, regenerate, never edit generated files directly. See [CodeGenSpecs/Overview.md](CodeGenSpecs/Overview.md).
