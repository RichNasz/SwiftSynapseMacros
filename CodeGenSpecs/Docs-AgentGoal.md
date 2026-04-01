# Spec: @AgentGoal Reference Article

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/AgentGoal.md`

## Purpose

A dedicated DocC reference article for the `#AgentGoal` freestanding macro. Readers arrive here wanting to understand what validation it performs, what metadata it generates, and what the parameters do. This macro is distinct from the other three — it's freestanding (expression macro), not attached.

## DocC Metadata

```
@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}
```

Targets the `AgentGoal(_:maxTurns:temperature:requiresTools:preferredFormat:)` macro symbol.

## Article Structure

### Overview (~3 sentences)

`#AgentGoal` is a freestanding expression macro applied to a string literal. At compile time it validates the prompt and generates a companion `AgentGoalMetadata` value named `<variable>_metadata`. At runtime the original string evaluates to itself — the macro has no runtime overhead, only compile-time validation and metadata generation.

Clarify the difference from attached macros: `#AgentGoal` is invoked inline with `#`, not as an attribute with `@`.

### Syntax

```swift
let goal = #AgentGoal("Prompt text", maxTurns: 10, temperature: 0.7)
// Generates: let goal_metadata = AgentGoalMetadata(maxTurns: 10, temperature: 0.7, ...)
```

### Parameters

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| _(prompt)_ | `String` literal | required | The goal/prompt text for the agent |
| `maxTurns` | `Int` | `nil` | Maximum tool-use rounds before forcing completion |
| `temperature` | `Double` | `nil` | LLM sampling temperature (0–2) |
| `requiresTools` | `Bool` | `false` | Warn at compile time if no tools are registered |
| `preferredFormat` | `TextFormat` | `nil` | Preferred output format (`.text` or `.jsonSchema`) |

### Generated Peer

A `AgentGoalMetadata` value named `<variableName>_metadata`:

| Field | Type | Source |
|-------|------|--------|
| `validatedPrompt` | `String` | The validated prompt literal |
| `maxTurns` | `Int?` | From parameter |
| `temperature` | `Double?` | From parameter |
| `requiresTools` | `Bool` | From parameter |
| `preferredFormat` | `TextFormat?` | From parameter |

### Compile-Time Validation (Errors)

| Condition | Error Message |
|-----------|--------------|
| Empty string literal | `Goal prompt cannot be empty` |
| `maxTurns < 1` | `maxTurns must be at least 1` |
| `temperature < 0 || temperature > 2` | `temperature must be between 0 and 2` |

### Compile-Time Warnings

The macro warns (not errors) when the prompt is missing common agentic keywords that help LLMs reason through complex tasks:

| Missing keyword pattern | Warning |
|------------------------|---------|
| "think step-by-step" or similar | `Consider adding reasoning instructions` |
| "use tools" or similar | `Goal requires tools but prompt doesn't mention tool use` |
| "FINAL ANSWER" or similar | `Consider specifying how the agent should signal completion` |

These are warnings only — the code compiles. Suppress with `#AgentGoal(_:)` syntax (omit optional parameters).

### Full Example

```swift
import SwiftSynapseHarness

let researchGoal = #AgentGoal(
    "Research the topic thoroughly. Think step-by-step. Use tools to gather information. Respond with FINAL ANSWER when done.",
    maxTurns: 15,
    temperature: 0.3,
    requiresTools: true
)
// researchGoal == "Research the topic thoroughly..."
// researchGoal_metadata.maxTurns == Optional(15)
// researchGoal_metadata.temperature == Optional(0.3)

// Use at runtime:
let result = try await agent.run(goal: researchGoal)
```

Show using `researchGoal_metadata` to configure the tool loop:

```swift
let result = try await AgentToolLoop.run(
    client: client, config: config, goal: researchGoal,
    tools: tools, transcript: _transcript,
    maxTurns: researchGoal_metadata.maxTurns
)
```

## Tone and Length

Reference article. Aim for ~350–450 words of prose plus tables and code blocks. The compile-time validation section is the most important — make it easy to find what error corresponds to what mistake.
