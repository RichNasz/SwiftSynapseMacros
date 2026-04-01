# Macro Reference

Detailed reference for all four SwiftSynapseMacros macros.

## Overview

SwiftSynapseMacros provides four attached macros. Each generates members on the annotated declaration and emits compile-time diagnostics if applied to the wrong declaration kind.

## @SpecDrivenAgent

Generates lifecycle scaffolding on an `actor` declaration: `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`, and `AgentExecutable` conformance.

### Target Type

`actor` only. Applying to any other declaration kind emits:

> error: @SpecDrivenAgent can only be applied to an actor

### Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `_status` | stored property | `AgentStatus` | private |
| `_transcript` | stored property | `ObservableTranscript` | private |
| `status` | computed property | `AgentStatus` | internal |
| `transcript` | computed property | `ObservableTranscript` | internal |
| `run(goal:)` | method | `async throws -> String` | internal |

### AgentStatus Cases

- `idle` — initial state
- `running` — after `run(goal:)` is called
- `paused` — agent paused
- `error(Error)` — after a failure
- `completed(Any)` — after successful completion with result

### run(goal:) Behavior

The generated `run(goal:)` calls the free function `agentRun()`, which:

1. Validates the goal is non-empty
2. Sets status to `.running` and resets transcript
3. Fires `.agentStarted` hook (can block)
4. Emits `.agentStarted` telemetry
5. Calls your `execute(goal:)` with domain logic
6. On success: sets status to `.completed`, fires `.agentCompleted` hook, emits telemetry
7. On cancellation: sets status to `.idle`, fires `.agentCancelled` hook
8. On error: sets status to `.error`, fires `.agentFailed` hook, emits telemetry
9. Optionally saves session via `SessionStore`

### Example

```swift
@SpecDrivenAgent
actor MyAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    // You implement this — the macro generates run(goal:)
    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        return try await AgentToolLoop.run(
            client: client, config: config, goal: goal,
            tools: ToolRegistry(), transcript: _transcript
        )
    }
}
```

## @StructuredOutput

Generates a `textFormat` static property on a `struct` declaration for JSON schema output formatting.

### Target Type

`struct` only. Applying to any other declaration kind emits:

> error: @StructuredOutput can only be applied to a struct

### Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `textFormat` | static computed property | `TextFormat` | internal |

The generated property returns `.jsonSchema(name: "<TypeName>", schema: Self.jsonSchema, strict: true)`. The struct must have a `jsonSchema` static property, typically provided by `@LLMToolArguments`.

### Example

```swift
@LLMToolArguments
@StructuredOutput
struct SearchResult {
    let title: String
    let url: String
    let relevance: Double
}
```

## @Capability

Generates an `agentTools()` method bridging `@LLMTool` types to `AgentToolDefinition`.

### Target Type

`struct` or `class`. Applying to any other declaration kind emits:

> error: @Capability can only be applied to a struct or class

### Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `agentTools()` | method | `() -> [AgentTool]` | internal |

### Example

```swift
@Capability
struct WebSearch {
    // Generates: func agentTools() -> [AgentTool]
}
```

## @AgentGoal

Validates prompt strings at compile time and generates `AgentGoalMetadata` with configurable parameters.

### Target Type

Applied to string literal expressions. Validates that:
- The prompt is non-empty
- No invalid parameters are specified
- Warns about agentic keywords that may need review

### Generated Peer

| Peer | Type | Purpose |
|------|------|---------|
| `AgentGoalMetadata` | struct | Configurable parameters: `maxTurns`, `temperature`, `requiresTools`, `preferredFormat` |

### Example

```swift
@AgentGoal(maxTurns: 10, temperature: 0.7, requiresTools: true)
let researchGoal = "Research the given topic thoroughly"
```

## Diagnostics Summary

| Macro | Diagnostic ID | Message |
|-------|--------------|---------|
| `@SpecDrivenAgent` | `requiresActor` | `@SpecDrivenAgent can only be applied to an actor` |
| `@StructuredOutput` | `requiresStruct` | `@StructuredOutput can only be applied to a struct` |
| `@Capability` | `requiresStructOrClass` | `@Capability can only be applied to a struct or class` |
| `@AgentGoal` | various | Empty prompt, invalid parameters, agentic keyword warnings |
