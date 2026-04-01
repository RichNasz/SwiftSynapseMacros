<!-- Generated from CodeGenSpecs/Docs-HowTo-SpecDrivenAgent.md — Do not edit manually. Update spec and re-generate. -->

# Using @SpecDrivenAgent

@Metadata {
    @PageKind(article)
}

Common tasks when building agents with `@SpecDrivenAgent`: creating an agent, observing state, working with the transcript, handling errors, and adding hooks.

## Overview

For the complete list of generated members, diagnostics, and `run(goal:)` behavior, see <doc:SpecDrivenAgent>. This guide focuses on what you'll do day-to-day.

## Create a Minimal Agent

Annotate an `actor` with `@SpecDrivenAgent` and implement `execute(goal:)`. The macro generates `run(goal:)` — call `run(goal:)` from your app; do not call `execute(goal:)` directly.

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

`AgentConfiguration.fromEnvironment()` reads `SWIFTSYNAPSE_SERVER_URL`, `SWIFTSYNAPSE_MODEL`, and `SWIFTSYNAPSE_API_KEY` from environment variables.

## Observe Agent Status in SwiftUI

The generated `status: AgentStatus` and `transcript: ObservableTranscript` properties are safe to read from the main actor. `ObservableTranscript` is `@Observable` — SwiftUI views that read it update automatically.

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

`AgentStatusView` and `TranscriptView` are from `SwiftSynapseUI` (part of the `SwiftSynapseHarness` package). For non-SwiftUI apps, check `await agent.status` after `run(goal:)` returns.

## Append to the Transcript from Inside execute(goal:)

Inside `execute(goal:)`, the private `_transcript` property is available. Use it to record progress, intermediate results, or any `TranscriptEntry` you want visible in the UI.

```swift
func execute(goal: String) async throws -> String {
    _transcript.append(.assistantMessage("Starting research..."))

    let results = try await fetchData(query: goal)
    _transcript.append(.assistantMessage("Found \(results.count) results. Synthesizing..."))

    return try await synthesize(results)
}
```

These entries appear immediately in `transcript.entries` (the public property), so SwiftUI views update in real time as the agent works.

## Handle Errors Correctly

Two error types matter:

**`AgentLifecycleError`** — thrown by the generated `run(goal:)` before `execute(goal:)` is called:
- `.emptyGoal` — the caller passed an empty string
- `.blockedByHook(reason:)` — a hook blocked execution

**Domain errors** — thrown by your `execute(goal:)`. These are rethrown by `run(goal:)` and reflected as `.error(error)` in `status`.

```swift
do {
    let result = try await agent.run(goal: userInput)
    displayResult(result)
} catch AgentLifecycleError.emptyGoal {
    showAlert("Please enter a goal before running the agent.")
} catch AgentLifecycleError.blockedByHook(let reason) {
    showAlert("Blocked: \(reason)")
} catch {
    // Domain error from execute() — already in agent.status
    showAlert("Agent failed: \(error.localizedDescription)")
}
```

After any error, `await agent.status` returns `.error(theError)` for inspection without re-throwing.

## Add a Hook to Intercept Execution

Hooks observe and optionally block agent events without modifying `execute(goal:)`. Create an `AgentHookPipeline`, add a `ClosureHook`, and pass it to `agentRun()` directly (advanced usage bypassing the macro-generated `run(goal:)`):

```swift
import SwiftSynapseHarness

let hooks = AgentHookPipeline()
let logger = ClosureHook(on: [.agentStarted, .agentCompleted, .agentFailed]) { event in
    switch event {
    case .agentStarted(let goal):   print("[Agent] Started: \(goal)")
    case .agentCompleted(let result): print("[Agent] Completed: \(result.prefix(80))")
    case .agentFailed(let error):   print("[Agent] Failed: \(error)")
    default: break
    }
    return .proceed
}
await hooks.add(logger)

// Pass hooks directly to agentRun():
let result = try await agentRun(agent: myAgent, goal: goal, hooks: hooks)
```

For tool-level hooks (`.preToolUse`, `.postToolUse`), pass the hook pipeline to `AgentToolLoop.run()` inside your `execute(goal:)`. See the `SwiftSynapseHarness` documentation for the complete hook event reference.

## Topics

### Reference
- <doc:SpecDrivenAgent>
