<!-- Generated from CodeGenSpecs/Docs-SpecDrivenAgent.md — Do not edit manually. Update spec and re-generate. -->

# ``SpecDrivenAgent()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}

Generates lifecycle scaffolding on an actor so it can run as an autonomous AI agent.

## Overview

`@SpecDrivenAgent` is applied to an `actor` declaration. It generates stored properties, computed accessors, and a `run(goal:)` method — all the boilerplate that would otherwise be identical across every agent you write. The actor conforms to `AgentExecutable` automatically.

You implement `execute(goal:)` with your domain logic. The generated `run(goal:)` calls `agentRun()` (from SwiftSynapseHarness) which handles goal validation, status transitions, transcript reset, hook firing, telemetry, and error surfacing.

> Important: `execute(goal:)` is the **implementation entry point** — only the framework calls it internally. `run(goal:)` is the **caller's entry point** — it's what you call from your app or tests. Never call `execute(goal:)` directly from outside the actor.

## Target Declaration

`actor` only. Applying `@SpecDrivenAgent` to any other declaration kind is a compile-time error:

```swift
@SpecDrivenAgent
class MyAgent { }
// error: @SpecDrivenAgent can only be applied to an actor
```

## Generated Members

| Member | Kind | Type | Access | Notes |
|--------|------|------|--------|-------|
| `_status` | stored property | `AgentStatus` | private | Backing store; mutated by `run(goal:)` |
| `_transcript` | stored property | `ObservableTranscript` | private | Available inside `execute(goal:)` via `_transcript` |
| `status` | computed property | `AgentStatus` | internal | Read from outside the actor |
| `transcript` | computed property | `ObservableTranscript` | internal | Read from outside the actor |
| `run(goal:)` | method | `async throws -> String` | internal | Generated lifecycle coordinator |

The macro also adds `AgentExecutable` conformance via `@attached(extension, conformances: AgentExecutable)`.

## run(goal:) Behavior

The generated `run(goal:)` delegates to `agentRun()` and executes this sequence:

1. Validates `goal` is non-empty — throws `AgentLifecycleError.emptyGoal` and sets `_status = .error(...)` if empty
2. Sets `_status = .running` and calls `_transcript.reset()`
3. Fires `.agentStarted(goal:)` hook — if any hook returns `.block(reason:)`, throws `AgentLifecycleError.blockedByHook(reason:)` and sets `_status = .error(...)`
4. Emits `.agentStarted` telemetry
5. Calls your `execute(goal:)` with domain logic
6. **On success:** sets `_status = .completed(result)`, fires `.agentCompleted(result:)` hook, emits telemetry, returns result
7. **On `CancellationError`:** sets `_status = .idle`, fires `.agentCancelled` hook
8. **On any other error:** sets `_status = .error(error)`, fires `.agentFailed(error:)` hook, emits telemetry, rethrows

## AgentStatus Cases

| Case | When set |
|------|----------|
| `.idle` | Initial state; after task cancellation |
| `.running` | After `run(goal:)` is called |
| `.paused` | Agent explicitly paused |
| `.error(Error)` | After empty goal, blocked hook, or `execute()` failure |
| `.completed(Any)` | After successful return from `execute()` |

## Compile-Time Diagnostics

| ID | Kind | Message |
|----|------|---------|
| `requiresActor` | error | `@SpecDrivenAgent can only be applied to an actor` |

## Example

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
actor WeatherAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    // You implement execute(goal:) — the macro generates run(goal:)
    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let tools = ToolRegistry()
        tools.register(FetchWeatherTool())
        return try await AgentToolLoop.run(
            client: client, config: config,
            goal: goal, tools: tools, transcript: _transcript
        )
    }
}

// Caller:
let agent = try WeatherAgent(configuration: try .fromEnvironment())
let forecast = try await agent.run(goal: "What is the weather in London?")
print(forecast)
// agent.status == .completed("What is the weather in London?")
// agent.transcript.entries contains the full conversation
```

`status` and `transcript` are `@Observable`-aware — reading them inside a SwiftUI `body` automatically subscribes to updates.

## Topics

### How-To Guides
- <doc:HowTo-SpecDrivenAgent>
