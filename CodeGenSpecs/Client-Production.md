# Spec: Production Capabilities

**Generates:**
- `Sources/SwiftSynapseMacrosClient/SessionPersistence.swift`
- `Sources/SwiftSynapseMacrosClient/Guardrails.swift`
- `Sources/SwiftSynapseMacrosClient/ToolProgress.swift`
- `Sources/SwiftSynapseMacrosClient/MCP.swift`
- `Sources/SwiftSynapseMacrosClient/ContextCompression.swift`
- `Sources/SwiftSynapseMacrosClient/ConfigurationHierarchy.swift`
- `Sources/SwiftSynapseMacrosClient/Caching.swift`
- `Sources/SwiftSynapseMacrosClient/DenialTracking.swift`
- `Sources/SwiftSynapseMacrosClient/AgentCoordination.swift`
- `Sources/SwiftSynapseMacrosClient/PluginSystem.swift`

## Overview

Production capabilities that close the gap between SwiftSynapse and production agent harnesses. Each capability is modular, opt-in, and integrates with the core harness via established extension points (hooks, telemetry, tool loop parameters).

---

## Session Persistence

Persistence layer for `AgentSession` snapshots. Enables pause/resume workflows.

- `SessionStore` protocol: `save/load/list/delete` — abstract backend (async throws, Sendable)
- `SessionMetadata`: Lightweight summary (id, agentType, goal, timestamps, status)
- `SessionStatus` enum: `.active`, `.paused`, `.completed`, `.failed`
- `FileSessionStore` actor: JSON file-per-session in configurable directory (`~/.swiftsynapse/sessions/`)
- **Integration:** `agentRun()` accepts optional `sessionStore`, auto-saves on completion/error/cancel
- **Hook events:** `.sessionSaved(sessionId:)`, `.sessionRestored(sessionId:)`

---

## Guardrails

Input/output safety checks for content filtering and compliance.

- `GuardrailInput` enum: `.toolArguments(toolName:arguments:)`, `.llmOutput(text:)`, `.userInput(text:)`
- `GuardrailDecision` enum: `.allow`, `.sanitize(replacement:)`, `.block(reason:)`, `.warn(reason:)`
- `RiskLevel` enum: `.low`, `.medium`, `.high`, `.critical`
- `GuardrailPolicy` protocol: `name: String`, `evaluate(input:) async -> GuardrailDecision`
- `ContentFilter` struct: Regex-based PII/secret detection. Default patterns: credit cards, SSNs, API keys, bearer tokens.
- `GuardrailPipeline` actor: Ordered evaluation, most-restrictive-wins (`.block` > `.sanitize` > `.warn` > `.allow`)
- `GuardrailError`: `.blocked(policy:reason:)`
- **Integration:** `AgentToolLoop.run()` accepts optional `guardrails` parameter. Checks before tool dispatch (on arguments) and after LLM response (on output text).
- **Telemetry:** `.guardrailTriggered(policy:risk:)`
- **Hook event:** `.guardrailTriggered(policy:decision:input:)`

---

## Tool Progress Streaming

Real-time feedback during long-running tool execution.

- `ToolProgressUpdate` struct: callId, toolName, message, fractionComplete (0.0–1.0, nil for indeterminate), metadata dict
- `ToolProgressDelegate` protocol: `reportProgress(_:) async`
- `ProgressReportingTool` protocol: Refines `AgentToolProtocol` with `execute(input:callId:progress:)`. Default implementation bridges to standard `execute(input:)`.
- **Integration:** `AnyAgentTool` detects conformance and forwards delegate. `ToolRegistry.dispatch()` and `dispatchBatch()` accept optional `progressDelegate`. `AgentToolLoop.run()` threads delegate through.
- **UI binding:** `ObservableTranscript.toolProgress: [String: ToolProgressUpdate]` — active progress keyed by callId, with `updateToolProgress(_:)` and `clearToolProgress(callId:)` methods.

---

## MCP (Model Context Protocol) Integration

Connect agents to external systems via the MCP standard (JSON-RPC 2.0).

### Transport Layer
- `MCPTransport` protocol: `send(_:)`, `receive() -> AsyncThrowingStream`, `close()`
- `StdioMCPTransport` actor: Communicates via stdin/stdout of a child `Process`. Content-Length header framing.
- Future: `SSEMCPTransport`, `WebSocketMCPTransport` (Foundation URLSession-based)

### Message Types
- `MCPMessage`: JSON-RPC 2.0 (jsonrpc, id, method, params, result, error)
- `MCPError`: code, message, data
- `AnyCodable`: Type-erased JSON value for dynamic params/results

### Connection Management
- `MCPServerConfig`: name, transport type, command/args, URL, environment
- `MCPTransportType` enum: `.stdio`, `.sse`, `.webSocket`
- `MCPServerConnection` actor: Connect, initialize handshake, discover tools, call tools, disconnect
- `MCPConnectionError`: `.notConnected`, `.missingCommand`, `.unsupportedTransport`, `.handshakeFailed`

### Tool Bridge
- `MCPToolBridge`: Wraps MCP-discovered tool as `AgentToolProtocol` (JSON pass-through input/output)
- `MCPToolDefinition`: Tool definition from MCP server (name, description, inputSchema)
- `MCPManager` actor: Manages multiple servers. `addServer()`, `discoverTools()`, `registerAll(in:)`, `disconnectAll()`

### Integration
- `AgentConfiguration` can include `mcpServers: [MCPServerConfig]` (future)
- MCP tools registered as normal `AgentToolProtocol` tools in `ToolRegistry`
- No external dependencies — Foundation covers stdio (`Process`), SSE (`URLSession`), WebSocket

---

## Advanced Context Compression

Multiple compression strategies beyond the basic `SlidingWindowCompressor`.

- `CompactionTrigger` enum: `.threshold(Double)`, `.tokenCount(Int)`, `.entryCount(Int)`, `.manual`. Default: `.threshold(0.8)`. Method: `shouldCompact(budget:entryCount:) -> Bool`.
- `MicroCompactor`: Truncates individual tool results exceeding `maxResultLength` (default 2048 chars).
- `ImportanceCompressor`: Scores entries by type (user > error > assistant > reasoning > toolCall > toolResult). Drops lowest-scored first, protects first and last entries. Configurable scoring function.
- `AutoCompactCompressor`: Aggressive compression keeping first entry + last N entries + summary.
- `CompositeCompressor`: Chains compressors in order. `.default` = [MicroCompactor → ImportanceCompressor → SlidingWindowCompressor].
- **Integration:** `AgentToolLoop.run()` accepts `compactionTrigger` parameter (replaces hardcoded 0.8 threshold). Emits `.contextCompacted` telemetry on compression.

---

## Configuration Hierarchy

7-level priority configuration for enterprise deployments.

- `ConfigurationPriority` enum: `.environment(1)` < `.remoteConfig(2)` < `.mdmPolicy(3)` < `.userFile(4)` < `.projectFile(5)` < `.localFile(6)` < `.cliArguments(7)`
- `ConfigurationSource` protocol: `priority`, `load() async throws -> [String: String]`
- **Built-in sources:**
  - `EnvironmentConfigSource`: Reads `SWIFTSYNAPSE_*` env vars, strips prefix, lowercases keys
  - `FileConfigSource`: JSON file reader. Statics: `.userDefault` (~/.swiftsynapse/config.json), `.projectDefault` (./swiftsynapse.json)
  - `MDMConfigSource`: macOS UserDefaults managed domain (enterprise MDM profiles)
- `ConfigurationResolver` actor: Merges sources by priority (higher overwrites lower). `resolve()` returns `[String: String]`. `resolveConfiguration(overrides:)` builds `AgentConfiguration`. Caches resolved values with `invalidate()`.

---

## Caching

Generic caching with LRU eviction and TTL for tool results.

- `CachePolicy`: maxEntries (default 100), TTL (default 5 min), eviction strategy
- `EvictionStrategy` enum: `.lru`, `.fifo`
- `Cache<Key: Hashable & Sendable, Value: Sendable>` actor: Generic cache. `get()` checks TTL, `set()` evicts at capacity. Thread-safe via actor isolation.
- `ToolResultCache` actor: Wraps `Cache<String, String>`. Keyed by `toolName:argsHash`. Methods: `get(toolName:arguments:)`, `set(toolName:arguments:result:)`, `invalidate(toolName:arguments:)`, `clear()`.

---

## Denial Tracking

Adaptive permission behavior based on consecutive denials.

- `PermissionMode` enum: `.default` (policy-driven), `.autoApprove` (trusted), `.alwaysPrompt` (force approval), `.planOnly` (block all, explain)
- `DenialTracker` actor: Tracks consecutive denials per tool. `recordDenial()`, `recordSuccess()` (resets count), `isThresholdExceeded()`. Configurable threshold (default 3).
- `AdaptivePermissionGate` actor: Wraps `PermissionGate` with mode + denial tracking. Behavior per mode:
  - `.autoApprove` → always allow
  - `.planOnly` → always deny with explanation
  - `.alwaysPrompt` → delegate to gate
  - `.default` → check denial threshold, then delegate to gate. Records success/denial.

---

## Multi-Agent Coordination

Dependency-aware multi-agent workflow execution.

- `SharedMailbox` actor: Cross-agent async message passing. `send(to:message:)`, `receive(for:) -> AsyncStream<String>`, `closeAll()`. Queues messages for offline agents.
- `TeamMemory` actor: Shared key-value store. `set()`, `get()`, `remove()`, `all()`, `clear()`. Visible to all agents in coordination.
- `CoordinationPhase<A: AgentExecutable>`: Named phase with goal, dependencies list, agent factory.
- `CoordinationResult`: phaseResults (keyed by name), total duration.
- `CoordinationRunner.run()`: Executes phases in waves — phases whose dependencies are all satisfied run in parallel. Validates dependency graph (unknown dependency, cyclic detection). Stores phase results in `TeamMemory` for downstream phases.
- `CoordinationError`: `.unknownDependency(phase:dependency:)`, `.cyclicDependency(phases:)`
- **Hook events:** `.coordinationPhaseStarted(phase:)`, `.coordinationPhaseCompleted(phase:)`

---

## Plugin System

Modular extension mechanism for agents.

- `AgentPlugin` protocol: `name`, `version`, `activate(context:) async throws`, `deactivate() async`
- `PluginContext` struct: Provides `toolRegistry`, `hookPipeline`, `guardrailPipeline?`, `configResolver?` for plugin registration
- `PluginManager` actor: `register()`, `activateAll(context:telemetry:)`, `deactivate(name:)`, `deactivateAll()`. Activates in registration order, deactivates in reverse.
- **Telemetry:** `.pluginActivated(name:)`, `.pluginError(name:error:)`
