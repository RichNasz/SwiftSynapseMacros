# Spec: HowTo — Combining All Four Macros

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/HowTo-CombiningMacros.md`

## Purpose

A task-oriented HowTo guide showing all four macros working together in a realistic agent. This is the "capstone" guide — readers who have read the individual macro guides land here to see the full picture. The code example should be substantive but not overwhelming: a research agent that uses tools, returns structured output, and uses a validated goal.

## DocC Metadata

```
@Metadata {
    @PageKind(article)
}
```

Title: `Combining All Four Macros`

## Article Structure

### Introduction (3–4 sentences)

The four macros are designed to be used together. `@SpecDrivenAgent` provides the agent scaffold, `@Capability` groups its tools, `@StructuredOutput` shapes its response type, and `#AgentGoal` validates and configures its prompt. This guide builds a complete agent — a research assistant that searches the web, returns a structured report, and is invoked with a compile-time validated goal. For individual macro reference pages, see `<doc:SpecDrivenAgent>`, `<doc:StructuredOutput>`, `<doc:Capability>`, and `<doc:AgentGoal>`.

---

### Step 1: Define the Response Type with @StructuredOutput

**Goal:** Create a Swift struct that the LLM will populate with structured research findings.

```swift
import SwiftSynapseHarness

@LLMToolArguments
@StructuredOutput
struct ResearchReport: Codable {
    let topic: String
    let summary: String
    let keyFindings: [String]
    let sources: [String]
    let confidence: Double   // 0.0 – 1.0
}
```

`@LLMToolArguments` generates the JSON schema; `@StructuredOutput` wraps it into `ResearchReport.textFormat`. The LLM will produce JSON matching this schema when `textFormat` is passed to the request.

---

### Step 2: Define Tools with @Capability

**Goal:** Create the tools the agent will use to gather information.

```swift
@Capability
struct ResearchTools {
    @LLMTool("webSearch", description: "Searches the web for information on a topic")
    func webSearch(query: String) async throws -> String {
        // search implementation
    }

    @LLMTool("fetchPage", description: "Fetches and extracts text from a web page URL")
    func fetchPage(url: String) async throws -> String {
        // fetch implementation
    }
}
```

`@Capability` generates `agentTools() -> [AgentTool]` on `ResearchTools`. The agent calls this to get the tool array for `ToolRegistry`.

---

### Step 3: Create the Agent with @SpecDrivenAgent

**Goal:** Wire everything together in the agent's `execute(goal:)`.

```swift
@SpecDrivenAgent
actor ResearchAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()

        // Tools from @Capability
        let tools = ToolRegistry()
        tools.register(contentsOf: ResearchTools().agentTools())

        // Run the tool loop with structured output format
        return try await AgentToolLoop.run(
            client: client, config: config,
            goal: goal, tools: tools, transcript: _transcript,
            outputFormat: ResearchReport.textFormat   // from @StructuredOutput
        )
    }
}
```

`@SpecDrivenAgent` generates `run(goal:)`, `status`, `transcript`, and `AgentExecutable` conformance. The author writes only `execute(goal:)`.

---

### Step 4: Invoke with a Validated Goal using #AgentGoal

**Goal:** Define the goal with compile-time validation and runtime configuration.

```swift
let researchGoal = #AgentGoal(
    """
    Research the given topic thoroughly.
    Use webSearch and fetchPage tools to gather current information.
    Think step-by-step through the findings.
    Respond with FINAL ANSWER when you have enough information.
    """,
    maxTurns: 20,
    temperature: 0.2,
    requiresTools: true,
    preferredFormat: ResearchReport.textFormat
)
```

`#AgentGoal` validates the prompt at compile time and generates `researchGoal_metadata` carrying the configuration.

---

### Step 5: Put It All Together

**Goal:** Run the agent and decode the structured response.

```swift
let agent = try ResearchAgent(configuration: try .fromEnvironment())
let jsonResponse = try await agent.run(goal: researchGoal)

// Decode the structured response
let data = jsonResponse.data(using: .utf8)!
let report = try JSONDecoder().decode(ResearchReport.self, from: data)

print("Topic:", report.topic)
print("Summary:", report.summary)
print("Key findings:")
for finding in report.keyFindings { print("  •", finding) }
print("Confidence:", Int(report.confidence * 100), "%")
```

---

### Which Macros Are Required vs Optional

End with a brief table clarifying that `@SpecDrivenAgent` is the only required macro for all agents:

| Macro | Required? | Use when |
|-------|-----------|----------|
| `@SpecDrivenAgent` | Yes — for all agents | Always |
| `@Capability` | No | Agent uses one or more tools |
| `@StructuredOutput` | No | Agent's final response should be JSON |
| `#AgentGoal` | No | You want compile-time prompt validation or per-goal LLM config |

The simplest possible agent uses only `@SpecDrivenAgent`. Add the others as your agent's requirements grow.

---

### Common Macro Pairings

Briefly note:
- `@LLMToolArguments` + `@StructuredOutput` — always together (`@LLMToolArguments` provides the schema that `@StructuredOutput` requires)
- `@Capability` + `@LLMTool` — always together (tools inside a capability type are annotated with `@LLMTool`)
- `#AgentGoal` — standalone, no required pairing

## Tone and Length

This is the showcase guide — it should feel complete and satisfying, not exhausting. Aim for ~600–700 words plus code blocks. The step-by-step structure is more important than depth in each step; readers can go to individual guides for details. End with the "required vs optional" table — it resets reader mental models and is highly scannable.
