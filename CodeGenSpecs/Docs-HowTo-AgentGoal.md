# Spec: HowTo — Using #AgentGoal

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/HowTo-AgentGoal.md`

## Purpose

A task-oriented HowTo guide for `#AgentGoal`. Readers arrive here wanting to validate prompts at compile time or configure LLM behavior (max turns, temperature) per-goal. The guide should make the runtime metadata access pattern clear — it's the non-obvious part.

## DocC Metadata

```
@Metadata {
    @PageKind(article)
}
```

Title: `Using #AgentGoal`

## Article Structure

### Introduction (2–3 sentences)

`#AgentGoal` validates prompt strings at compile time and generates a companion `AgentGoalMetadata` value you can use to configure the tool loop at runtime. This guide shows how to write validated goals, configure LLM parameters, use the generated metadata, and respond to compiler warnings. For the full parameter reference and diagnostic list, see `<doc:AgentGoal>`.

---

### Task 1: Validate a Prompt at Compile Time

**Goal:** Catch empty or obviously wrong prompts before the app runs.

Apply `#AgentGoal` to any string literal where you define a goal:

```swift
import SwiftSynapseHarness

// This compiles fine:
let researchGoal = #AgentGoal("Research Swift concurrency and summarize the key concepts.")

// This fails at compile time — empty string:
let badGoal = #AgentGoal("")
// error: Goal prompt cannot be empty
```

The macro also warns about prompts that may not produce good agentic behavior:

```swift
let vague = #AgentGoal("Do something.")
// warning: Consider adding reasoning instructions (e.g. "think step-by-step")
```

Respond to warnings by making the prompt more specific (see Task 4).

---

### Task 2: Configure LLM Behavior Per Goal

**Goal:** Set `maxTurns` and `temperature` on individual goals rather than globally.

Pass parameters after the prompt string:

```swift
// Cap tool-use at 5 rounds; use deterministic output:
let summaryGoal = #AgentGoal(
    "Summarize the document. Think step-by-step. Respond with FINAL ANSWER when done.",
    maxTurns: 5,
    temperature: 0.0
)

// Creative writing — higher temperature, no turn limit:
let storyGoal = #AgentGoal(
    "Write a short story about a robot learning to paint.",
    temperature: 1.2
)
```

`maxTurns` and `temperature` default to `nil` — meaning the tool loop uses whatever defaults your `AgentConfiguration` provides.

---

### Task 3: Use the Generated Metadata at Runtime

**Goal:** Pass `maxTurns` and `preferredFormat` from the goal metadata to the tool loop.

When you write `let researchGoal = #AgentGoal(...)`, the macro also generates `let researchGoal_metadata: AgentGoalMetadata`. Use its properties when calling `AgentToolLoop.run()`:

```swift
let researchGoal = #AgentGoal(
    "Research Swift macros thoroughly. Use tools. Think step-by-step. FINAL ANSWER when done.",
    maxTurns: 20,
    temperature: 0.2,
    requiresTools: true
)

func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let tools = ToolRegistry()
    tools.register(contentsOf: SearchTools().agentTools())

    return try await AgentToolLoop.run(
        client: client, config: config,
        goal: researchGoal,                              // validated prompt
        tools: tools, transcript: _transcript,
        maxTurns: researchGoal_metadata.maxTurns         // from metadata
    )
}
```

The metadata name is always `<variableName>_metadata`. If you define `let summaryGoal`, the metadata is `summaryGoal_metadata`.

---

### Task 4: Fix Common Compiler Warnings

**Goal:** Write prompts that satisfy the macro's agentic keyword checks.

The macro warns when a prompt is likely to produce poor results from an agentic model. Add the missing elements:

| Warning | Add to your prompt |
|---------|-------------------|
| Missing reasoning instruction | `"Think step-by-step."` or `"Reason through this carefully."` |
| Tool use not mentioned | `"Use the available tools to gather information."` |
| No completion signal | `"Respond with FINAL ANSWER: followed by your answer when done."` |

These are **warnings, not errors** — the code compiles without them. But including them consistently produces better agent behavior.

Well-formed prompt example:

```swift
let auditGoal = #AgentGoal(
    """
    Audit the provided codebase for security vulnerabilities.
    Think step-by-step through each file.
    Use the available tools to read files and check dependencies.
    Respond with FINAL ANSWER: followed by your findings when done.
    """,
    maxTurns: 30,
    requiresTools: true
)
```

## Tone and Length

Practical. The generated metadata name (`<variableName>_metadata`) is the single most non-obvious aspect — make it prominent. Aim for ~400–500 words plus code blocks. The warning table in Task 4 is more useful than prose.
