<!-- Generated from CodeGenSpecs/Docs-HowTo-AgentGoal.md — Do not edit manually. Update spec and re-generate. -->

# Using #AgentGoal

@Metadata {
    @PageKind(article)
}

How to validate prompts at compile time, configure LLM parameters per goal, and use the generated metadata at runtime.

## Overview

`#AgentGoal` catches empty or misconfigured prompts before your app runs and gives each goal its own LLM configuration. For the complete parameter and diagnostics reference, see <doc:AgentGoal>.

## Validate a Prompt at Compile Time

Apply `#AgentGoal` to a string literal. The macro validates it at build time:

```swift
import SwiftSynapseHarness

// Compiles fine:
let summaryGoal = #AgentGoal("Summarize the article and identify the three main points.")

// Fails at compile time:
let emptyGoal = #AgentGoal("")
// error: Goal prompt cannot be empty

// Fails at compile time:
let badTurns = #AgentGoal("Do research", maxTurns: 0)
// error: maxTurns must be at least 1
```

The macro also warns when a prompt may produce poor agentic behavior — but the code still compiles (see "Fix Common Compiler Warnings" below).

## Configure LLM Behavior Per Goal

Pass parameters after the prompt string to set `maxTurns`, `temperature`, and other options:

```swift
// Deterministic summary — cap at 5 tool rounds:
let summaryGoal = #AgentGoal(
    "Summarize the document. Think step-by-step. Respond with FINAL ANSWER when done.",
    maxTurns: 5,
    temperature: 0.0
)

// Creative writing — higher randomness, no round limit:
let storyGoal = #AgentGoal(
    "Write a short story about a robot learning to paint.",
    temperature: 1.2
)

// Research with tools — require tool use:
let researchGoal = #AgentGoal(
    "Research the topic using available tools. FINAL ANSWER when complete.",
    maxTurns: 20,
    temperature: 0.2,
    requiresTools: true
)
```

Unspecified parameters default to `nil`, meaning the tool loop uses whatever defaults your `AgentConfiguration` provides.

## Use the Generated Metadata at Runtime

When you write `let researchGoal = #AgentGoal(...)`, the macro also generates `let researchGoal_metadata: AgentGoalMetadata`. The metadata variable name is always `<variableName>_metadata`.

Access it when configuring the tool loop:

```swift
let researchGoal = #AgentGoal(
    "Research Swift macros. Use tools. Think step-by-step. FINAL ANSWER when done.",
    maxTurns: 20,
    temperature: 0.2
)

func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let tools = ToolRegistry()
    tools.register(contentsOf: SearchTools().agentTools())

    return try await AgentToolLoop.run(
        client: client, config: config,
        goal: researchGoal,                           // the validated string
        tools: tools, transcript: _transcript,
        maxTurns: researchGoal_metadata.maxTurns      // Optional(20)
    )
}
```

`researchGoal_metadata` fields:

| Field | Type | Value |
|-------|------|-------|
| `validatedPrompt` | `String` | The prompt literal |
| `maxTurns` | `Int?` | `Optional(20)` |
| `temperature` | `Double?` | `Optional(0.2)` |
| `requiresTools` | `Bool` | `false` |
| `preferredFormat` | `TextFormat?` | `nil` |

## Fix Common Compiler Warnings

The macro warns when a prompt is missing elements that help LLMs reason effectively. Add the suggested keywords to clear the warning:

| Warning | What to add |
|---------|------------|
| Missing reasoning instruction | `"Think step-by-step."` |
| Tool use not mentioned (when `requiresTools: true`) | `"Use the available tools."` |
| No completion signal | `"Respond with FINAL ANSWER when done."` |

A well-formed prompt that avoids all warnings:

```swift
let auditGoal = #AgentGoal(
    """
    Audit the provided codebase for security vulnerabilities.
    Think step-by-step through each component.
    Use the available tools to read files and inspect dependencies.
    Respond with FINAL ANSWER: followed by your findings when done.
    """,
    maxTurns: 30,
    requiresTools: true
)
```

These warnings are not errors — ignoring them is fine for simple prompts. They're most valuable when building multi-turn tool-using agents where prompt quality directly affects reliability.

## Topics

### Reference
- <doc:AgentGoal>
