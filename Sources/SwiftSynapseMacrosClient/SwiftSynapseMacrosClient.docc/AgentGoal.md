<!-- Generated from CodeGenSpecs/Docs-AgentGoal.md — Do not edit manually. Update spec and re-generate. -->

# ``AgentGoal(_:maxTurns:temperature:requiresTools:preferredFormat:)``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}

Validates a prompt string at compile time and generates a companion `AgentGoalMetadata` value with configurable LLM parameters.

## Overview

`#AgentGoal` is a freestanding expression macro applied to a string literal. At compile time it validates the prompt and generates a companion `AgentGoalMetadata` value named `<variable>_metadata`. At runtime the original string evaluates to itself — the macro has no runtime overhead, only compile-time validation and metadata generation.

Unlike the other three macros (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`), `#AgentGoal` is freestanding — it's invoked with `#`, not `@`:

```swift
let goal = #AgentGoal("Summarize the document.")
// goal == "Summarize the document."     (the string itself)
// goal_metadata                          (AgentGoalMetadata, compiler-generated)
```

## Parameters

| Parameter | Type | Default | Purpose |
|-----------|------|---------|---------|
| _(prompt)_ | `String` literal | required | The goal text to validate and pass to the agent |
| `maxTurns` | `Int` | `nil` | Maximum tool-use rounds before the loop is forced to complete |
| `temperature` | `Double` | `nil` | LLM sampling temperature (0.0–2.0) |
| `requiresTools` | `Bool` | `false` | Emits a warning if no tools are registered when this is `true` |
| `preferredFormat` | `TextFormat` | `nil` | Preferred output format (`.text` or `.jsonSchema(...)`) |

## Generated Peer

For a variable named `researchGoal`, the macro generates `researchGoal_metadata: AgentGoalMetadata`:

| Field | Type | Source |
|-------|------|--------|
| `validatedPrompt` | `String` | The validated prompt literal |
| `maxTurns` | `Int?` | From parameter |
| `temperature` | `Double?` | From parameter |
| `requiresTools` | `Bool` | From parameter |
| `preferredFormat` | `TextFormat?` | From parameter |

## Compile-Time Validation — Errors

| Condition | Error Message |
|-----------|--------------|
| Empty string literal | `Goal prompt cannot be empty` |
| `maxTurns < 1` | `maxTurns must be at least 1` |
| `temperature < 0.0` or `> 2.0` | `temperature must be between 0 and 2` |

## Compile-Time Validation — Warnings

The macro warns when the prompt lacks common patterns that help LLMs reason effectively through agentic tasks. These are warnings only — the code compiles.

| Missing element | Warning guidance |
|----------------|-----------------|
| Reasoning instruction | Add `"Think step-by-step."` or `"Reason through this carefully."` |
| Tool use mention | Add `"Use the available tools to gather information."` |
| Completion signal | Add `"Respond with FINAL ANSWER when done."` |

## Example

```swift
import SwiftSynapseHarness

let researchGoal = #AgentGoal(
    """
    Research the topic thoroughly.
    Think step-by-step. Use the available tools.
    Respond with FINAL ANSWER when done.
    """,
    maxTurns: 20,
    temperature: 0.2,
    requiresTools: true
)
// researchGoal == "Research the topic thoroughly..."
// researchGoal_metadata.maxTurns == Optional(20)
// researchGoal_metadata.temperature == Optional(0.2)
// researchGoal_metadata.requiresTools == true
```

Use the metadata when configuring the tool loop:

```swift
func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let tools = ToolRegistry()
    tools.register(contentsOf: SearchTools().agentTools())

    return try await AgentToolLoop.run(
        client: client, config: config,
        goal: researchGoal,
        tools: tools, transcript: _transcript,
        maxTurns: researchGoal_metadata.maxTurns   // Optional(20)
    )
}
```

The metadata variable name is always `<variableName>_metadata`. If you write `let summaryGoal = #AgentGoal(...)`, the metadata is `summaryGoal_metadata`.

## Topics

### How-To Guides
- <doc:HowTo-AgentGoal>
