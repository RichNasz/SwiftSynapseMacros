# Spec: Agent Harness Types

**Generates:**
- `Sources/SwiftSynapseMacrosClient/AgentToolProtocol.swift`
- `Sources/SwiftSynapseMacrosClient/ToolRegistry.swift`
- `Sources/SwiftSynapseMacrosClient/AgentToolLoop.swift`
- `Sources/SwiftSynapseMacrosClient/StreamingToolExecutor.swift`
- `Sources/SwiftSynapseMacrosClient/AgentHook.swift`
- `Sources/SwiftSynapseMacrosClient/AgentHookPipeline.swift`
- `Sources/SwiftSynapseMacrosClient/Permission.swift`
- `Sources/SwiftSynapseMacrosClient/ToolListPolicy.swift`
- `Sources/SwiftSynapseMacrosClient/AgentLLMClient.swift`
- `Sources/SwiftSynapseMacrosClient/AgentConfiguration.swift`
- `Sources/SwiftSynapseMacrosClient/AgentSession.swift`
- `Sources/SwiftSynapseMacrosClient/RetryWithBackoff.swift`
- `Sources/SwiftSynapseMacrosClient/RecoveryStrategy.swift`
- `Sources/SwiftSynapseMacrosClient/ContextBudget.swift`
- `Sources/SwiftSynapseMacrosClient/Telemetry.swift`
- `Sources/SwiftSynapseMacrosClient/TelemetrySinks.swift`
- `Sources/SwiftSynapseMacrosClient/SubagentContext.swift`

## Overview

The agent harness is the runtime layer that orchestrates agent execution. It provides the complete infrastructure between the macro-generated scaffolding and the developer's domain logic in `execute(goal:)`.

These types were designed to match production agent harness capabilities while remaining Swift-native (actors, structured concurrency, `@Observable`).

---

## AgentToolProtocol

Typed, self-describing tool interface. Each tool declares its `Input`/`Output` associated types, a `name`, `description`, JSON schema via `inputSchema`, and a concurrency safety flag.

```swift
public protocol AgentToolProtocol: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable
    static var name: String { get }
    static var description: String { get }
    static var inputSchema: FunctionToolParam { get }
    static var isConcurrencySafe: Bool { get }  // default: false
    func execute(input: Input) async throws -> Output
}
```

**Internal:** `AnyAgentTool` — Type-erased wrapper enabling heterogeneous storage in `ToolRegistry`. Handles JSON decode of input, execution, and JSON encode of output. String outputs bypass JSON encoding to avoid double-quoting. Supports `ProgressReportingTool` forwarding.

**Types:** `ToolResult` (callId, name, output, duration, success), `ToolDispatchError` (unknownTool, loopExceeded, decodingFailed, encodingFailed, blockedByHook, permissionDenied)

---

## ToolRegistry

Thread-safe registry using `NSLock`. Register tools at init, dispatch by name at runtime.

- `register<T: AgentToolProtocol>(_:)` — Stores as `AnyAgentTool`
- `dispatch(name:callId:arguments:progressDelegate:)` — Single tool execution with permission check
- `dispatchBatch(_:progressDelegate:)` — Concurrency-safe tools run in `TaskGroup`; unsafe run sequentially
- `definitions()` — Returns `[FunctionToolParam]` for LLM request
- `permissionGate` — Optional `PermissionGate` checked before each dispatch

---

## AgentToolLoop

The reusable tool dispatch loop. Two variants:

### `run()` (synchronous)
Parameters: client, config, goal, tools, transcript, systemPrompt, maxIterations, hooks, telemetry, budget (inout), compressor, recovery, guardrails, progressDelegate, compactionTrigger.

Flow per iteration:
1. Check cancellation
2. Check compaction trigger → compress if needed
3. Build `AgentRequest`
4. Fire `.llmRequestSent` hook (can block/modify)
5. Send with `retryWithBackoff`; on failure attempt recovery
6. Track tokens in budget
7. Fire `.llmResponseReceived` hook
8. If no tool calls → check output guardrails → return result
9. Fire `.preToolUse` hook (can block)
10. Check argument guardrails per tool call
11. Dispatch tools via registry (with progress delegate)
12. Emit per-tool telemetry
13. Record results in transcript
14. Fire `.postToolUse` hook
15. Check budget exhaustion

### `runStreaming()` (stream-aware)
Same loop but uses `StreamingToolExecutor` to dispatch concurrency-safe tools as their definitions complete in the LLM stream. Text deltas forwarded to transcript streaming state.

---

## AgentHook System

### Events (15 kinds)
`agentStarted`, `agentCompleted`, `agentFailed`, `agentCancelled`, `preToolUse`, `postToolUse`, `llmRequestSent`, `llmResponseReceived`, `transcriptUpdated`, `sessionSaved`, `sessionRestored`, `guardrailTriggered`, `coordinationPhaseStarted`, `coordinationPhaseCompleted`

### Actions
`proceed` — continue normally, `modify(String)` — replace input/output, `block(reason:)` — abort

### Protocol
`AgentHook` — `subscribedEvents: Set<AgentHookEventKind>`, `handle(_:) async -> HookAction`

### Convenience
`ClosureHook(on:handler:)` — Closure-based hook for quick setup

### Pipeline
`AgentHookPipeline` actor — `add()`, `fire()` with first-block-wins semantics

---

## Permission System

- `ToolPermission` enum: `.allowed`, `.requiresApproval(reason:)`, `.denied(reason:)`
- `PermissionPolicy` protocol: `evaluate(toolName:arguments:) async -> ToolPermission`
- `ApprovalDelegate` protocol: `requestApproval(toolName:arguments:reason:) async -> Bool`
- `PermissionGate` actor: Evaluates policies in order, most-restrictive-wins. Invokes delegate for `.requiresApproval`.
- `ToolListPolicy`: Built-in list-based policy with `.allow()`, `.deny()`, `.requireApproval()` rules.
- `PermissionError`: `.denied(tool:reason:)`, `.noApprovalDelegate(tool:)`, `.rejected(tool:)`

---

## AgentLLMClient

Backend-agnostic LLM abstraction with three implementations:

- `AgentLLMClient` protocol: `send(_:)`, `stream(_:)`, `streamEvents(_:)`
- `AgentRequest`: model, userPrompt, systemPrompt, tools, timeoutSeconds, previousResponseId, maxTokens
- `AgentResponse`: text, toolCalls, responseId, inputTokens, outputTokens
- `AgentStreamEvent`: `.textDelta(String)`, `.toolCall(AgentToolCall)`, `.responseComplete(id, inputTokens, outputTokens)`
- `CloudLLMClient` actor: Wraps SwiftOpenResponsesDSL
- `HybridLLMClient` actor: Foundation Models → cloud fallback
- `AgentConfiguration.buildClient()` / `buildLLMClient()` extensions

---

## AgentConfiguration

Centralized config with environment resolution:

```swift
public struct AgentConfiguration: Codable, Sendable {
    executionMode: ExecutionMode  // .onDevice, .cloud, .hybrid
    serverURL: String?
    modelName: String
    apiKey: String?
    timeoutSeconds: Int           // default: 300
    maxRetries: Int               // default: 3
    toolResultBudgetTokens: Int   // default: 4096
}
```

- `fromEnvironment(overrides:)` — Resolves from `SWIFTSYNAPSE_*` env vars
- `Overrides` struct for caller-supplied values
- Validation: URL format, non-empty model, positive timeout, retries 1–10

---

## Recovery System

- `RecoverableError` enum: `contextWindowExceeded`, `outputTruncated`, `apiError`
- `RecoveryStrategy` protocol: `attemptRecovery(from:state:transcript:compressor:budget:)`
- `RecoveryResult`: `.recovered(continuationPrompt:)`, `.cannotRecover`
- `RecoveryState`: Tracks attempted strategies, recovery count, max output token overrides
- **Built-in strategies:** `ReactiveCompactionStrategy`, `OutputTokenEscalationStrategy`, `ContinuationStrategy`
- `RecoveryChain`: Ordered chain, first success wins. `.default` = [Compaction → Escalation → Continuation]
- `classifyRecoverableError()` helper

---

## Subagent Support

- `SubagentContext`: Inherited config, tools, hooks, telemetry, lifecycle mode, system prompt, max iterations
- `SubagentLifecycleMode`: `.independent` (own task) or `.shared` (parent cancellation propagates)
- `SubagentResult`: output, transcript, duration, success
- `SubagentRunner.run()` — Single child agent
- `SubagentRunner.runParallel()` — Multiple children in `TaskGroup`, results in input order

---

## Telemetry

- `TelemetryEvent`: timestamp, kind, agentType, sessionId
- `TelemetryEventKind`: agentStarted, agentCompleted, agentFailed, llmCallMade, toolCalled, retryAttempted, tokenBudgetExhausted, guardrailTriggered, contextCompacted, pluginActivated, pluginError
- `TelemetrySink` protocol: `emit(_:)`
- `TokenUsageTracker` actor: Cumulative token tracking
- **Built-in sinks:** `OSLogTelemetrySink`, `InMemoryTelemetrySink`, `CompositeTelemetrySink`

---

## Context Budget

- `ContextBudget`: maxTokens, usedTokens, remaining, isExhausted, utilizationPercentage, record(), reset()
- `TranscriptCompressor` protocol: `compress(entries:budget:) -> [TranscriptEntry]`
- `SlidingWindowCompressor`: Keep last N entries + summary of dropped

---

## Session Snapshot

- `AgentSession`: Codable snapshot with sessionId, agentType, goal, transcriptEntries, completedStepIndex, customState, timestamps
- `CodableTranscriptEntry`: Bridge for non-Codable TranscriptEntry, with to/from conversion

---

## Retry

- `retryWithBackoff()`: Generic exponential backoff (baseDelay 500ms, doubles per attempt)
- `isTransportRetryable()`: Default predicate for network errors
