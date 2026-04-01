# Spec: @SpecDrivenAgent Reference Article

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/SpecDrivenAgent.md`

## Purpose

A dedicated DocC reference article for the `@SpecDrivenAgent` macro. This is the primary macro in the package — most readers will land here first. The article should be authoritative but approachable: technical precision for the generated members, plain language for the conceptual explanation.

## DocC Metadata

```
@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}
```

Targets the `SpecDrivenAgent()` macro symbol. Uses `mergeBehavior: override` so this article fully replaces auto-generated symbol documentation.

## Article Structure

### Overview (~3–4 sentences)

`@SpecDrivenAgent` is applied to an `actor` declaration. It generates lifecycle scaffolding — stored properties, computed accessors, and `run(goal:)` — so the actor conforms to `AgentExecutable` without boilerplate. The author implements `execute(goal:)` with domain logic; `run(goal:)` handles everything else: empty-goal validation, status transitions, transcript reset, hook firing, telemetry, and error surfacing.

Key distinction to state clearly: **`execute(goal:)` is the implementation entry point; `run(goal:)` is the caller's entry point.** Never call `execute(goal:)` directly from outside the actor.

### Target Declaration

Actor only. Show the error emitted for non-actor targets:

```
@SpecDrivenAgent
class MyAgent { }  // error: @SpecDrivenAgent can only be applied to an actor
```

### Generated Members Table

| Member | Kind | Type | Access | Notes |
|--------|------|------|--------|-------|
| `_status` | stored property | `AgentStatus` | private | Backing store; mutated by `run(goal:)` |
| `_transcript` | stored property | `ObservableTranscript` | private | Available inside `execute(goal:)` |
| `status` | computed property | `AgentStatus` | internal | Read from outside the actor |
| `transcript` | computed property | `ObservableTranscript` | internal | Read from outside the actor |
| `run(goal: String) async throws -> String` | method | — | internal | Generated lifecycle coordinator |

Also adds `AgentExecutable` conformance via `@attached(extension, conformances: AgentExecutable)`.

### run(goal:) Behavior

Document the exact sequence as a numbered list:

1. Validates `goal` is non-empty — throws `AgentLifecycleError.emptyGoal` and sets `_status = .error(...)` if empty
2. Sets `_status = .running` and calls `_transcript.reset()`
3. Fires `.agentStarted(goal:)` hook — if any hook returns `.block(reason:)`, throws `AgentLifecycleError.blockedByHook(reason:)` and sets `_status = .error(...)`
4. Emits `.agentStarted` telemetry event
5. Calls `execute(goal:)` — the author-implemented method
6. On success: sets `_status = .completed(result)`, fires `.agentCompleted(result:)` hook, emits telemetry, returns result
7. On `CancellationError`: sets `_status = .idle`, fires `.agentCancelled` hook
8. On any other error: sets `_status = .error(error)`, fires `.agentFailed(error:)` hook, emits telemetry, rethrows

### AgentStatus Cases

Brief table:

| Case | When |
|------|------|
| `.idle` | Initial state; after cancellation |
| `.running` | After `run(goal:)` is called |
| `.paused` | Agent explicitly paused |
| `.error(Error)` | After empty goal, blocked hook, or execute() failure |
| `.completed(Any)` | After successful return from execute() |

### Compile-Time Diagnostics

| ID | Kind | Message |
|----|------|---------|
| `requiresActor` | error | `@SpecDrivenAgent can only be applied to an actor` |

### Full Example

A minimal but realistic example using `import SwiftSynapseHarness`. Show the actor, the `init`, the `execute(goal:)` calling through the tool loop, and a caller running via `run(goal:)`.

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
actor WeatherAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

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
```

After the example, note that `status` and `transcript` are observable from any SwiftUI view that holds a reference to the agent.

## Tone and Length

Reference article — precise and complete. Aim for ~400–500 words of prose plus the tables and code block. Do not editorialize; every sentence should add information.
