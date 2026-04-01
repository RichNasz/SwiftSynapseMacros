<!-- Generated from CodeGenSpecs/Docs-StructuredOutput.md — Do not edit manually. Update spec and re-generate. -->

# ``StructuredOutput()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}

Generates a `textFormat` property that tells the LLM to respond with JSON matching the struct's schema.

## Overview

`@StructuredOutput` is applied to a `struct` declaration. It generates a single static computed property — `textFormat: TextFormat` — that packages the struct's JSON schema into the format the LLM client uses to request structured output.

It is almost always paired with `@LLMToolArguments` (from SwiftLLMToolMacros), which generates the `jsonSchema` static property that `@StructuredOutput` wraps. Apply `@LLMToolArguments` first:

```swift
@LLMToolArguments   // generates jsonSchema
@StructuredOutput   // generates textFormat using jsonSchema
struct MyResponse: Codable { ... }
```

## Target Declaration

`struct` only. Applying `@StructuredOutput` to any other declaration kind is a compile-time error:

```swift
@StructuredOutput
actor MyAgent { }
// error: @StructuredOutput can only be applied to a struct
```

## Required Precondition

The annotated struct must have a `static var jsonSchema: JSONSchema` property. In practice, `@LLMToolArguments` provides this. If the property is absent, compilation fails with a missing member error at the generated `textFormat`'s reference to `Self.jsonSchema`.

## Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `textFormat` | static computed property | `TextFormat` | internal |

Generated body:

```swift
static var textFormat: TextFormat {
    .jsonSchema(name: "StructName", schema: Self.jsonSchema, strict: true)
}
```

`"StructName"` is replaced with the actual type name at code-generation time. `strict: true` instructs the LLM to produce JSON that exactly matches the schema.

## TextFormat Values

| Value | Meaning |
|-------|---------|
| `.jsonSchema(name:schema:strict:)` | LLM responds with JSON matching the schema |
| `.text` | LLM responds with plain text (default when `textFormat` is not used) |

Pass `MyStruct.textFormat` to the LLM client request to activate structured output mode.

## Compile-Time Diagnostics

| ID | Kind | Message |
|----|------|---------|
| `requiresStruct` | error | `@StructuredOutput can only be applied to a struct` |

## Example

```swift
import SwiftSynapseHarness

@LLMToolArguments
@StructuredOutput
struct WeatherReport: Codable {
    let city: String
    let temperatureCelsius: Double
    let conditions: String
    let humidity: Int
}

// WeatherReport.textFormat is now available:
// .jsonSchema(name: "WeatherReport", schema: WeatherReport.jsonSchema, strict: true)

// Use in an agent:
func execute(goal: String) async throws -> String {
    let client = try config.buildClient()
    let response = try await client.complete(
        prompt: "What is the weather in \(goal)?",
        format: WeatherReport.textFormat
    )
    // response.text contains JSON matching the schema
    let data = response.text.data(using: .utf8)!
    let report = try JSONDecoder().decode(WeatherReport.self, from: data)
    return "\(report.city): \(report.temperatureCelsius)°C, \(report.conditions)"
}
```

## Topics

### How-To Guides
- <doc:HowTo-StructuredOutput>
