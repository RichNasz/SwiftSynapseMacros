# Agent Harness Guide

The runtime infrastructure between your `execute(goal:)` and a working agent — typed tools, hooks, permissions, recovery, streaming, and subagents.

## Overview

The agent harness provides everything an agent needs at runtime. Each component is opt-in and composes naturally through function parameters — no subclassing, no protocol witnesses, no configuration objects.

## Typed Tool System

Tools conform to `AgentToolProtocol` with typed `Input` and `Output`:

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

Register tools in a `ToolRegistry` and dispatch by name:

```swift
let tools = ToolRegistry()
tools.register(CalculateTool())
tools.register(ConvertUnitTool())

// Single dispatch
let result = try await tools.dispatch(name: "calculate", callId: "1", arguments: json)

// Batch dispatch — concurrency-safe tools run in parallel via TaskGroup
let results = try await tools.dispatchBatch(calls)
```

`AnyAgentTool` handles type erasure internally. String outputs bypass JSON encoding to avoid double-quoting.

## AgentToolLoop

The reusable tool dispatch loop handles the complete LLM conversation cycle:

```swift
let result = try await AgentToolLoop.run(
    client: client,
    config: config,
    goal: goal,
    tools: tools,
    transcript: _transcript,
    systemPrompt: "You are a helpful assistant.",
    maxIterations: 10,
    hooks: hooks,
    telemetry: telemetry,
    budget: &budget,
    compressor: compressor,
    recovery: recovery,
    guardrails: guardrails,
    progressDelegate: delegate,
    compactionTrigger: .threshold(0.75)
)
```

Each iteration: check cancellation → compact if needed → build request → fire hooks → send to LLM → track tokens → dispatch tools → record results → check budget.

### Streaming Variant

`AgentToolLoop.runStreaming()` dispatches concurrency-safe tools as their definitions complete in the LLM stream. Text deltas are forwarded to `ObservableTranscript` for real-time SwiftUI updates.

## Hook System

Intercept 15 event types without modifying agent code:

| Event | When it fires |
|-------|---------------|
| `agentStarted` | Agent begins execution |
| `agentCompleted` | Agent finishes successfully |
| `agentFailed` | Agent encounters an error |
| `agentCancelled` | Agent task is cancelled |
| `preToolUse` | Before tool dispatch (can block) |
| `postToolUse` | After tool dispatch |
| `llmRequestSent` | Before LLM call (can modify) |
| `llmResponseReceived` | After LLM response |
| `transcriptUpdated` | Transcript entry added |
| `sessionSaved` | Session persisted |
| `sessionRestored` | Session restored |
| `guardrailTriggered` | Guardrail policy activated |
| `coordinationPhaseStarted` | Coordination phase begins |
| `coordinationPhaseCompleted` | Coordination phase ends |

### Hook Actions

- `.proceed` — continue normally
- `.modify(String)` — replace input/output
- `.block(reason:)` — abort the operation

### Quick Setup

```swift
let hooks = AgentHookPipeline()

let auditHook = ClosureHook(on: [.preToolUse, .postToolUse]) { event in
    // Log tool usage
    return .proceed
}
await hooks.add(auditHook)
```

The pipeline uses first-block-wins semantics — if any hook returns `.block`, the operation is aborted.

## Permission System

Policy-driven tool access control with human-in-the-loop approval:

```swift
let gate = PermissionGate()
await gate.addPolicy(ToolListPolicy(rules: [
    .allow(["calculate", "convertUnit"]),
    .requireApproval(["chargeCard", "sendEmail"]),
    .deny(["deleteAccount"])
]))
await gate.setApprovalDelegate(myDelegate)

tools.permissionGate = gate
```

Policies evaluate in order with most-restrictive-wins semantics. For `.requiresApproval`, the gate calls your `ApprovalDelegate` for a human decision.

## Recovery Strategies

Self-healing from context window exhaustion and output truncation:

| Strategy | Recovers from |
|----------|--------------|
| `ReactiveCompactionStrategy` | Context window exceeded — compresses transcript |
| `OutputTokenEscalationStrategy` | Output truncated — increases max tokens |
| `ContinuationStrategy` | Output truncated — sends continuation prompt |

Chain them with `RecoveryChain`:

```swift
let recovery = RecoveryChain.default
// Tries: Compaction → Escalation → Continuation (first success wins)
```

## Context Budget

Track token usage and trigger compaction:

```swift
var budget = ContextBudget(maxTokens: 128_000)
// AgentToolLoop records tokens automatically
// When budget.utilizationPercentage exceeds threshold, compaction fires
```

### Transcript Compression

`TranscriptCompressor` protocol with built-in `SlidingWindowCompressor` (keep last N entries + summary). Advanced compressors available in `ContextCompression.swift` — see <doc:ProductionGuide>.

## LLM Backend Abstraction

Three backends behind one protocol:

```swift
public protocol AgentLLMClient: Sendable {
    func send(_ request: AgentRequest) async throws -> AgentResponse
    func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<AgentStreamEvent, Error>
}
```

| Backend | Implementation |
|---------|---------------|
| `CloudLLMClient` | Wraps SwiftOpenResponsesDSL for any OpenAI-compatible endpoint |
| `HybridLLMClient` | Foundation Models on-device first, cloud fallback |

`AgentConfiguration.buildClient()` selects based on `executionMode`.

## Subagent Composition

Run child agents with shared or independent lifecycles:

```swift
let result = try await SubagentRunner.run(
    agentFactory: { try SummaryAgent(configuration: $0) },
    goal: "Summarize this document",
    context: SubagentContext(config: parentConfig, lifecycleMode: .shared)
)
```

- `.shared` — parent cancellation propagates to the child
- `.independent` — child runs in its own task

Run multiple children in parallel:

```swift
let results = try await SubagentRunner.runParallel(
    agents: [
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research topic A"),
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research topic B"),
    ],
    context: SubagentContext(config: config, lifecycleMode: .shared)
)
```

## Telemetry

Structured event emission to any backend:

```swift
let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),       // Unified logging
    InMemoryTelemetrySink(),    // Testing
])
```

11 event types: agent lifecycle, LLM calls (model, tokens, duration), tool calls (name, duration, success), retries, budget exhaustion, guardrail triggers, context compaction, plugin lifecycle.

## Retry

Exponential backoff for transient failures:

```swift
let result = try await retryWithBackoff(maxRetries: 3) {
    try await client.send(request)
}
```

Base delay 500ms, doubles per attempt. `isTransportRetryable()` provides a default predicate for network errors.
