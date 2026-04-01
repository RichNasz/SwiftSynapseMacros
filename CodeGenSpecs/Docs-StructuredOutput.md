# Spec: @StructuredOutput Reference Article

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/StructuredOutput.md`

## Purpose

A dedicated DocC reference article for the `@StructuredOutput` macro. Readers arrive here after encountering the macro name and wanting to know exactly what it generates, what it requires, and when to use it. Keep it concise — this macro generates one member.

## DocC Metadata

```
@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}
```

Targets the `StructuredOutput()` macro symbol.

## Article Structure

### Overview (~2–3 sentences)

`@StructuredOutput` is applied to a `struct` declaration. It generates a `static var textFormat: TextFormat` property that packages the struct's JSON schema into the format the LLM client uses to request structured (JSON) output. It is almost always used together with `@LLMToolArguments`, which provides the `jsonSchema` static property that `@StructuredOutput` wraps.

### Target Declaration

`struct` only. Show the error emitted for other types:

```
@StructuredOutput
actor MyAgent { }  // error: @StructuredOutput can only be applied to a struct
```

### Required Precondition

The annotated struct must have a `static var jsonSchema: JSONSchema` property available. In practice this is provided by `@LLMToolArguments` from SwiftLLMToolMacros. If the property is absent, the code will not compile (missing member error at the generated property's reference site).

### Generated Members Table

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `textFormat` | static computed property | `TextFormat` | internal |

Generated body:

```swift
static var textFormat: TextFormat {
    .jsonSchema(name: "StructName", schema: Self.jsonSchema, strict: true)
}
```

Where `"StructName"` is substituted with the actual type name at code-generation time.

### TextFormat Context

Briefly explain `TextFormat`:
- `.jsonSchema(name:schema:strict:)` — tells the LLM to respond with JSON matching the provided schema
- `.text` — plain text response (the default when `textFormat` is not set)

Pass `MyStruct.textFormat` to the LLM client request to activate structured output.

### Compile-Time Diagnostics

| ID | Kind | Message |
|----|------|---------|
| `requiresStruct` | error | `@StructuredOutput can only be applied to a struct` |

### Full Example

```swift
import SwiftSynapseHarness

@LLMToolArguments
@StructuredOutput
struct WeatherReport {
    let city: String
    let temperatureCelsius: Double
    let conditions: String
}

// WeatherReport.textFormat is now available:
// .jsonSchema(name: "WeatherReport", schema: WeatherReport.jsonSchema, strict: true)
```

Show how `textFormat` is used in a request:

```swift
let response = try await client.complete(
    prompt: "What is the weather in London?",
    format: WeatherReport.textFormat
)
let report = try JSONDecoder().decode(WeatherReport.self, from: response.jsonData)
```

## Tone and Length

Concise reference. Aim for ~200–300 words of prose plus the tables and code blocks. This macro is simple — don't over-explain it.
