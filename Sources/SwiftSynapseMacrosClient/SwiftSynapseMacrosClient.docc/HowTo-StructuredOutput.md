<!-- Generated from CodeGenSpecs/Docs-HowTo-StructuredOutput.md — Do not edit manually. Update spec and re-generate. -->

# Using @StructuredOutput

@Metadata {
    @PageKind(article)
}

How to get structured JSON responses from an LLM using `@StructuredOutput`: define a response struct, request JSON, and decode the result.

## Overview

`@StructuredOutput` tells the LLM to respond with JSON matching your struct's schema. The three-step pattern is: define the struct, request structured output, decode the response. For the complete generated member reference, see <doc:StructuredOutput>.

## Define a Struct for Structured Output

Apply `@LLMToolArguments` first (it generates `jsonSchema`), then `@StructuredOutput` (it generates `textFormat` using that schema). Add `Codable` for decoding.

```swift
import SwiftSynapseHarness

@LLMToolArguments
@StructuredOutput
struct SentimentAnalysis: Codable {
    let sentiment: String   // "positive", "negative", or "neutral"
    let confidence: Double  // 0.0 – 1.0
    let reasoning: String
}
```

The macro application order matters: `@LLMToolArguments` must appear first (outermost) because `@StructuredOutput` references the `jsonSchema` it generates.

What each annotation contributes:
- `@LLMToolArguments` → `static var jsonSchema: JSONSchema` (the schema describing the struct's properties)
- `@StructuredOutput` → `static var textFormat: TextFormat` (packages the schema for the LLM client)
- `Codable` → enables `JSONDecoder` to decode the LLM's response

## Request Structured Output from the LLM

Inside `execute(goal:)`, pass `SentimentAnalysis.textFormat` to the client:

```swift
func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let response = try await client.complete(
        prompt: "Analyze the sentiment of: \(goal)",
        format: SentimentAnalysis.textFormat
    )
    // response.text contains JSON matching SentimentAnalysis's schema
    return response.text
}
```

With `strict: true` (embedded in `textFormat`), the LLM is constrained to produce JSON that exactly matches the schema — no extra fields, no missing fields.

## Decode the Response

Decode the returned JSON string into your Swift type:

```swift
// In the caller, after agent.run(goal:) returns:
let json = try await agent.run(goal: "This product is absolutely terrible.")
let data = json.data(using: .utf8)!
let analysis = try JSONDecoder().decode(SentimentAnalysis.self, from: data)

print(analysis.sentiment)    // "negative"
print(analysis.confidence)   // 0.95
print(analysis.reasoning)    // "Strong negative language..."
```

Or decode inside `execute(goal:)` and return a formatted string:

```swift
func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let response = try await client.complete(
        prompt: "Analyze: \(goal)",
        format: SentimentAnalysis.textFormat
    )
    guard let data = response.text.data(using: .utf8) else {
        throw AgentError.invalidResponse
    }
    let analysis = try JSONDecoder().decode(SentimentAnalysis.self, from: data)
    return "\(analysis.sentiment) (\(Int(analysis.confidence * 100))%): \(analysis.reasoning)"
}
```

## When to Use Structured Output

Good use cases:
- Extracting structured data from text (entities, dates, classifications)
- Generating responses your app processes programmatically, not just displays
- Sentiment analysis, scoring, ranking

Skip structured output for:
- Conversational agents — plain text is simpler and works well
- Tool-using agents where the *tool results* are already typed — structured output applies to the agent's *final answer*

## Topics

### Reference
- <doc:StructuredOutput>
