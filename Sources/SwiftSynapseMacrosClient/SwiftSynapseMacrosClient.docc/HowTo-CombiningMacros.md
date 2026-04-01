<!-- Generated from CodeGenSpecs/Docs-HowTo-CombiningMacros.md — Do not edit manually. Update spec and re-generate. -->

# Combining All Four Macros

@Metadata {
    @PageKind(article)
}

Build a complete agent that uses `@SpecDrivenAgent`, `@Capability`, `@StructuredOutput`, and `#AgentGoal` together.

## Overview

The four macros are designed to be composed. `@SpecDrivenAgent` provides the agent scaffold, `@Capability` groups its tools, `@StructuredOutput` shapes its response type, and `#AgentGoal` validates and configures its prompt. This guide builds a research assistant that demonstrates all four macros working together.

For individual macro reference pages, see <doc:SpecDrivenAgent>, <doc:StructuredOutput>, <doc:Capability>, and <doc:AgentGoal>.

## Step 1: Define the Response Type

Use `@StructuredOutput` to specify what the agent returns. The LLM will populate this struct with its findings.

```swift
import SwiftSynapseHarness

@LLMToolArguments
@StructuredOutput
struct ResearchReport: Codable {
    let topic: String
    let summary: String
    let keyFindings: [String]
    let sources: [String]
    let confidence: Double    // 0.0 – 1.0
}
```

`@LLMToolArguments` generates `jsonSchema`; `@StructuredOutput` generates `textFormat` wrapping that schema. Passing `ResearchReport.textFormat` to the LLM client tells it to respond with JSON matching this struct.

## Step 2: Define Tools

Use `@Capability` to group the tools the agent will use:

```swift
@Capability
struct ResearchTools {
    @LLMTool("webSearch", description: "Searches the web for information on a topic")
    func webSearch(query: String) async throws -> String {
        // search implementation
    }

    @LLMTool("fetchPage", description: "Fetches and extracts text content from a URL")
    func fetchPage(url: String) async throws -> String {
        // fetch implementation
    }
}
```

`@Capability` generates `ResearchTools().agentTools()` — a `[AgentTool]` array ready for `ToolRegistry`.

## Step 3: Create the Agent

Use `@SpecDrivenAgent` to generate lifecycle scaffolding. Wire the tools and output format in `execute(goal:)`:

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

        // Run the tool loop; LLM responds in ResearchReport's JSON schema
        return try await AgentToolLoop.run(
            client: client, config: config,
            goal: goal, tools: tools, transcript: _transcript,
            outputFormat: ResearchReport.textFormat    // from @StructuredOutput
        )
    }
}
```

`@SpecDrivenAgent` generates `run(goal:)`, `status`, `transcript`, and `AgentExecutable` conformance. You write only `execute(goal:)`.

## Step 4: Define the Goal

Use `#AgentGoal` to validate the prompt at compile time and attach LLM configuration:

```swift
let researchGoal = #AgentGoal(
    """
    Research the given topic thoroughly.
    Use webSearch and fetchPage tools to gather current, reliable information.
    Think step-by-step through the findings before forming conclusions.
    Respond with FINAL ANSWER when you have sufficient information.
    """,
    maxTurns: 20,
    temperature: 0.2,
    requiresTools: true,
    preferredFormat: ResearchReport.textFormat
)
// researchGoal_metadata.maxTurns == Optional(20)
```

## Step 5: Run the Agent and Decode the Response

```swift
let agent = try ResearchAgent(configuration: try .fromEnvironment())
let jsonResponse = try await agent.run(goal: researchGoal)

let data = jsonResponse.data(using: .utf8)!
let report = try JSONDecoder().decode(ResearchReport.self, from: data)

print("Topic:", report.topic)
print("Summary:", report.summary)
print("Confidence:", Int(report.confidence * 100), "%")
print("Key findings:")
for finding in report.keyFindings { print("  •", finding) }
```

## Which Macros Are Required vs Optional

`@SpecDrivenAgent` is the only required macro. The others add capabilities as your agent's needs grow:

| Macro | Required? | Add when |
|-------|-----------|----------|
| `@SpecDrivenAgent` | **Yes** | Always — provides the agent scaffold |
| `@Capability` | No | The agent calls one or more tools |
| `@StructuredOutput` | No | The agent's final answer should be JSON |
| `#AgentGoal` | No | You want compile-time prompt validation or per-goal LLM config |

## Common Macro Pairings

| Always together | Why |
|----------------|-----|
| `@LLMToolArguments` + `@StructuredOutput` | `@StructuredOutput` requires the `jsonSchema` that `@LLMToolArguments` generates |
| `@Capability` + `@LLMTool` | Tools inside a `@Capability` type are annotated with `@LLMTool` |

| Standalone | Notes |
|-----------|-------|
| `#AgentGoal` | No required pairing — validate any string literal |
| `@SpecDrivenAgent` | Works alone for a minimal agent with no tools or structured output |

## Topics

### Reference
- <doc:SpecDrivenAgent>
- <doc:StructuredOutput>
- <doc:Capability>
- <doc:AgentGoal>
