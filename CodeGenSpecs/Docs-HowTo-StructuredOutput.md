# Spec: HowTo — Using @StructuredOutput

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/HowTo-StructuredOutput.md`

## Purpose

A task-oriented HowTo guide for `@StructuredOutput`. Readers arrive here wanting to get JSON responses from an LLM and decode them into Swift types. The guide should make the `@LLMToolArguments` + `@StructuredOutput` + decode pattern feel natural.

## DocC Metadata

```
@Metadata {
    @PageKind(article)
}
```

Title: `Using @StructuredOutput`

## Article Structure

### Introduction (2 sentences)

`@StructuredOutput` tells the LLM to respond with JSON matching your struct's schema. This guide shows how to define a struct for structured output, request it from the LLM, and decode the response. For the generated member reference, see `<doc:StructuredOutput>`.

---

### Task 1: Define a Struct for Structured Output

**Goal:** Create a Swift struct that carries both JSON schema (for the LLM) and Codable conformance (for decoding).

Apply `@LLMToolArguments` first (generates `jsonSchema`), then `@StructuredOutput` (generates `textFormat`). Add `Codable` for decoding.

```swift
import SwiftSynapseHarness

@LLMToolArguments
@StructuredOutput
struct SentimentAnalysis: Codable {
    let sentiment: String      // "positive", "negative", or "neutral"
    let confidence: Double     // 0.0 – 1.0
    let reasoning: String      // brief explanation
}
```

Explain the roles:
- `@LLMToolArguments` generates `static var jsonSchema: JSONSchema` describing the struct's properties
- `@StructuredOutput` generates `static var textFormat: TextFormat` wrapping that schema
- `Codable` enables `JSONDecoder` to decode the LLM's response

The macro application order matters: `@LLMToolArguments` must appear before `@StructuredOutput` (outermost first in Swift attribute lists means it's applied first).

---

### Task 2: Request Structured Output from the LLM

**Goal:** Pass `textFormat` to the LLM client so it responds with JSON.

Inside `execute(goal:)`, pass `SentimentAnalysis.textFormat` to the client:

```swift
func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let response = try await client.complete(
        prompt: goal,
        format: SentimentAnalysis.textFormat
    )
    // response.text contains JSON matching the schema
    return response.text
}
```

The LLM receives the JSON schema and is instructed to respond with `strict: true`, meaning it must produce JSON that matches the schema exactly.

---

### Task 3: Decode the Response

**Goal:** Convert the LLM's JSON text into a Swift value.

Decode inside `execute(goal:)` before returning, or in the caller after `run(goal:)` returns:

```swift
// Inside execute(goal:) — return a decoded struct's description
func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let response = try await client.complete(
        prompt: "Analyze the sentiment: \(goal)",
        format: SentimentAnalysis.textFormat
    )

    guard let data = response.text.data(using: .utf8) else {
        throw AgentError.invalidResponse
    }
    let analysis = try JSONDecoder().decode(SentimentAnalysis.self, from: data)
    return "\(analysis.sentiment) (\(Int(analysis.confidence * 100))% confidence): \(analysis.reasoning)"
}
```

Or in the caller if you want the raw struct:

```swift
let json = try await agent.run(goal: "This product is amazing!")
let data = json.data(using: .utf8)!
let analysis = try JSONDecoder().decode(SentimentAnalysis.self, from: data)
print(analysis.sentiment)  // "positive"
```

---

### When to Use Structured Output

Briefly list good candidates:
- Extracting structured data from unstructured text (names, dates, entities)
- Sentiment analysis, classification, scoring
- Generating structured responses that your app processes further (not just displaying text)

And when *not* to use it:
- Conversational agents — plain text responses are simpler
- Tool-using agents — tools return their own typed results; structured output is for the *agent's final answer*

## Tone and Length

Practical, with emphasis on the decode pattern since that's the tricky part. Aim for ~400–500 words plus code blocks. Each task should be self-contained with a clear purpose statement.
