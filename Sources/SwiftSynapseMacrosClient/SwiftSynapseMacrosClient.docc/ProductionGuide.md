# Production Guide

Capabilities that close the gap between a working agent and a deployed one — session persistence, guardrails, MCP, compression, configuration, caching, coordination, and plugins.

## Overview

Every capability in this guide is modular and opt-in. They integrate through established extension points (function parameters, hook events, telemetry) rather than requiring changes to your agent's `execute(goal:)`.

## Session Persistence

Pause and resume agent workflows across app launches:

```swift
let store = FileSessionStore()

// agentRun() auto-saves on completion, error, or cancellation
try await agentRun(agent: myAgent, goal: "...", sessionStore: store)

// Resume later
if let session = try await store.load(sessionId: savedId) {
    myAgent._transcript.restore(from: session.transcriptEntries)
}
```

| Type | Purpose |
|------|---------|
| `SessionStore` | Protocol — `save`, `load`, `list`, `delete` |
| `SessionMetadata` | Lightweight summary (id, agentType, goal, timestamps, status) |
| `SessionStatus` | `.active`, `.paused`, `.completed`, `.failed` |
| `FileSessionStore` | Actor — JSON file-per-session in `~/.swiftsynapse/sessions/` |

Hook events: `.sessionSaved(sessionId:)`, `.sessionRestored(sessionId:)`.

## Guardrails

Input/output safety checks for content filtering and compliance:

```swift
let guardrails = GuardrailPipeline()
await guardrails.add(ContentFilter.default)

try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    guardrails: guardrails
)
```

`ContentFilter.default` detects credit card numbers, SSNs, API keys, and bearer tokens via regex patterns.

### Guardrail Decisions

- `.allow` — content passes
- `.sanitize(replacement:)` — replace sensitive content
- `.block(reason:)` — reject entirely (throws `GuardrailError`)
- `.warn(reason:)` — log but allow

The pipeline evaluates policies in order with most-restrictive-wins semantics. Checks run before tool dispatch (on arguments) and after LLM response (on output text).

### Custom Policies

```swift
struct ComplianceFilter: GuardrailPolicy {
    let name = "compliance"
    func evaluate(input: GuardrailInput) async -> GuardrailDecision {
        // Your compliance logic
    }
}
```

## Tool Progress Streaming

Real-time feedback during long-running tool execution:

```swift
struct DataImportTool: ProgressReportingTool {
    // ... AgentToolProtocol requirements ...

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

Progress updates flow to `ObservableTranscript.toolProgress` for SwiftUI binding.

## MCP Integration

Connect agents to external systems via the Model Context Protocol (JSON-RPC 2.0):

```swift
let manager = MCPManager()
try await manager.addServer(MCPServerConfig(
    name: "database",
    command: "/usr/local/bin/mcp-postgres",
    arguments: ["--connection", connectionString]
))
try await manager.registerAll(in: tools) // MCP tools appear as native tools
```

### Architecture

| Type | Purpose |
|------|---------|
| `MCPTransport` | Protocol — `send`, `receive`, `close` |
| `StdioMCPTransport` | Actor — stdio via child `Process` with Content-Length framing |
| `MCPServerConnection` | Actor — connect, handshake, discover tools, call tools |
| `MCPToolBridge` | Wraps MCP tool as `AgentToolProtocol` (JSON pass-through) |
| `MCPManager` | Actor — manages multiple servers, registers tools |

No external dependencies — Foundation covers stdio (`Process`), SSE (`URLSession`), and WebSocket.

## Advanced Context Compression

Multiple compression strategies beyond the basic `SlidingWindowCompressor`:

| Compressor | Strategy |
|------------|----------|
| `MicroCompactor` | Truncates individual tool results exceeding a length threshold |
| `ImportanceCompressor` | Scores entries by type (user > error > assistant > toolCall), drops lowest first |
| `AutoCompactCompressor` | Aggressive — keeps first entry + last N entries + summary |
| `CompositeCompressor` | Chains compressors in order |

```swift
let compressor = CompositeCompressor.default
// Chain: MicroCompactor → ImportanceCompressor → SlidingWindowCompressor

try await AgentToolLoop.run(
    ..., compressor: compressor,
    compactionTrigger: .threshold(0.75)
)
```

### Compaction Triggers

- `.threshold(Double)` — compress when budget utilization exceeds percentage (default 0.8)
- `.tokenCount(Int)` — compress when used tokens exceed count
- `.entryCount(Int)` — compress when transcript entry count exceeds limit
- `.manual` — never auto-compact

## Configuration Hierarchy

7-level priority configuration for enterprise deployments:

```
CLI arguments (7)  >  local file (6)  >  project file (5)  >
user file (4)  >  MDM policy (3)  >  remote config (2)  >  environment (1)
```

```swift
let resolver = ConfigurationResolver()
await resolver.addSource(EnvironmentConfigSource())
await resolver.addSource(FileConfigSource.userDefault)   // ~/.swiftsynapse/config.json
await resolver.addSource(MDMConfigSource())              // macOS managed domain
let config = try await resolver.resolveConfiguration()
```

| Source | What it reads |
|--------|--------------|
| `EnvironmentConfigSource` | `SWIFTSYNAPSE_*` env vars, strips prefix, lowercases keys |
| `FileConfigSource` | JSON file at configurable path |
| `MDMConfigSource` | macOS UserDefaults managed domain (enterprise MDM profiles) |

## Caching

Generic caching with LRU eviction and TTL for tool results:

```swift
let cache = ToolResultCache(policy: CachePolicy(maxEntries: 50, ttl: .seconds(300)))
// Identical tool calls return cached results instantly
```

The underlying `Cache<Key, Value>` actor supports both `.lru` and `.fifo` eviction strategies. Thread-safe via actor isolation.

## Denial Tracking

Adaptive permission behavior based on consecutive denials:

```swift
let adaptiveGate = AdaptivePermissionGate(
    gate: baseGate,
    mode: .default,
    denialThreshold: 3
)
```

| Mode | Behavior |
|------|----------|
| `.default` | Policy-driven, tracks denials, switches at threshold |
| `.autoApprove` | Always allow (trusted environments) |
| `.alwaysPrompt` | Force approval for every tool call |
| `.planOnly` | Block all tools, explain what would have been called |

## Multi-Agent Coordination

Dependency-aware multi-agent workflow execution:

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

Phases with satisfied dependencies run in parallel. Results are stored in `TeamMemory` for downstream phases. `SharedMailbox` enables cross-agent async message passing.

The runner validates the dependency graph — `CoordinationError.unknownDependency` for missing references, `CoordinationError.cyclicDependency` for cycles.

## Plugin System

Modular extension mechanism — plugins register hooks, tools, and guardrails at activation:

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

`PluginContext` provides access to `toolRegistry`, `hookPipeline`, `guardrailPipeline`, and `configResolver`. Plugins activate in registration order and deactivate in reverse.

Telemetry: `.pluginActivated(name:)`, `.pluginError(name:error:)`.
