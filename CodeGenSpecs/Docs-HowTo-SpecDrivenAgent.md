# Spec: HowTo — Using @SpecDrivenAgent

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/HowTo-SpecDrivenAgent.md`

## Purpose

A task-oriented HowTo guide for `@SpecDrivenAgent`. Unlike the reference article, this is structured around what developers want to *accomplish*, not what the macro generates. Each section answers "how do I...?" with a minimal working code snippet and a brief explanation of why the approach works.

## DocC Metadata

```
@Metadata {
    @PageKind(article)
    @PageImage(purpose: icon, source: "")
}
```

Title: `Using @SpecDrivenAgent`

## Article Structure

### Introduction (2–3 sentences)

This guide shows common tasks when working with `@SpecDrivenAgent`: creating your first agent, observing its state, working with the transcript from inside `execute(goal:)`, handling errors, and adding hooks. For the complete list of generated members, see `<doc:SpecDrivenAgent>`.

---

### Task 1: Create a Minimal Agent

**Goal:** Get a `@SpecDrivenAgent` actor running that makes a single LLM call.

Show the complete pattern: package import, actor annotation, `init` taking `AgentConfiguration`, `execute(goal:)` calling the LLM client, and a caller invoking `run(goal:)`.

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
actor GreetingAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        return try await client.complete(prompt: goal)
    }
}

// Run:
let agent = try GreetingAgent(configuration: try .fromEnvironment())
let reply = try await agent.run(goal: "Say hello in three languages.")
print(reply)
```

Note: `run(goal:)` is the public entry point. The macro generates it — do not implement it yourself.

---

### Task 2: Observe Agent Status in SwiftUI

**Goal:** Show real-time agent status in a SwiftUI view.

The generated `status: AgentStatus` and `transcript: ObservableTranscript` properties are safe to read from the main actor via `await`. `ObservableTranscript` is `@Observable`, so SwiftUI views update automatically.

```swift
import SwiftSynapseHarness
import SwiftSynapseUI

struct AgentView: View {
    let agent: GreetingAgent

    var body: some View {
        VStack {
            AgentStatusView(status: agent.status)
            TranscriptView(transcript: agent.transcript)
        }
        .task {
            try? await agent.run(goal: "Describe the solar system.")
        }
    }
}
```

Explain: `agent.status` and `agent.transcript` are `@Observable`-aware — reading them inside a `body` automatically subscribes to changes. `AgentStatusView` and `TranscriptView` are from `SwiftSynapseUI` (in `SwiftSynapseHarness`).

Note for non-SwiftUI apps: observe status changes by polling `await agent.status` after `run(goal:)` returns, or use hooks (see Task 5).

---

### Task 3: Append to the Transcript from Inside execute(goal:)

**Goal:** Record custom events — progress messages, intermediate results — in the agent's transcript.

Inside `execute(goal:)`, `_transcript` (the private backing property) is available. Use `_transcript.append(_:)` to record any `TranscriptEntry`.

```swift
func execute(goal: String) async throws -> String {
    _transcript.append(.assistantMessage("Starting research..."))

    let results = try await fetchData(query: goal)
    _transcript.append(.assistantMessage("Found \(results.count) results."))

    let summary = try await summarize(results)
    return summary
}
```

These entries appear in `transcript.entries` (the public property), so any SwiftUI view showing the transcript will update in real time.

---

### Task 4: Handle Errors Correctly

**Goal:** Distinguish between lifecycle errors and domain errors; surface them appropriately.

Two error types matter:

**`AgentLifecycleError`** — thrown by the generated `run(goal:)` before `execute(goal:)` is called:
- `.emptyGoal` — caller passed an empty string
- `.blockedByHook(reason:)` — a hook blocked execution

**Domain errors** — thrown by `execute(goal:)` itself. These are rethrown by `run(goal:)` and set `status` to `.error(error)`.

```swift
do {
    let result = try await agent.run(goal: userInput)
    print("Result:", result)
} catch AgentLifecycleError.emptyGoal {
    showAlert("Please enter a goal before running the agent.")
} catch AgentLifecycleError.blockedByHook(let reason) {
    showAlert("Blocked: \(reason)")
} catch {
    // Domain error from execute() — already reflected in agent.status
    showAlert("Agent failed: \(error.localizedDescription)")
}
```

After any error, `await agent.status` returns `.error(theError)` for inspection.

---

### Task 5: Intercept Execution with Hooks

**Goal:** Log, audit, or block agent execution without modifying `execute(goal:)`.

Create an `AgentHookPipeline`, add a `ClosureHook`, and pass it to `agentRun()`. Because `run(goal:)` is macro-generated, hooks are provided through the harness layer — see `SwiftSynapseHarness` documentation for the full hook API.

```swift
import SwiftSynapseHarness

let hooks = AgentHookPipeline()
let logger = ClosureHook(on: [.agentStarted, .agentCompleted, .agentFailed]) { event in
    switch event {
    case .agentStarted(let goal): print("Started: \(goal)")
    case .agentCompleted(let result): print("Completed: \(result)")
    case .agentFailed(let error): print("Failed: \(error)")
    default: break
    }
    return .proceed
}
await hooks.add(logger)

// Pass hooks when calling agentRun() directly (advanced):
let result = try await agentRun(agent: myAgent, goal: goal, hooks: hooks)
```

Cross-reference: `<doc:IntegrationGuide>` explains how hooks integrate across the harness.

## Tone and Length

Task-oriented, practical. Each task section should be self-contained: a one-sentence "what you'll do," a code snippet, and 2–3 sentences explaining the key points. No theory beyond what's needed to understand the task. Aim for ~600–800 words total.
