# Macro Reference

Detailed reference for all three SwiftSynapseMacros macros.

## Overview

SwiftSynapseMacros provides three attached member macros. Each generates members on the annotated declaration and emits compile-time diagnostics if applied to the wrong declaration kind.

## @SpecDrivenAgent

Generates a complete agent scaffold on an `actor` declaration.

### Target Type

`actor` only. Applying to any other declaration kind emits:

> error: @SpecDrivenAgent can only be applied to an actor

### Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `Status` | enum | `String, Sendable` | internal |
| `_status` | stored property | `Status` | private |
| `_transcript` | stored property | `[TranscriptEntry]` | private |
| `_dslAgent` | stored property | `LLMClient?` | private |
| `status` | computed property | `Status` | internal |
| `isRunning` | computed property | `Bool` | internal |
| `transcript` | computed property | `[TranscriptEntry]` | internal |
| `client` | stored property | `LLMClient?` | internal |
| `run(_:)` | method | `async throws -> String` | internal |

### Status Enum Cases

- `idle` -- initial state
- `running` -- after `run(_:)` is called
- `completed` -- after successful response
- `failed` -- after an error

### run(_:) Behavior

1. Guards that `client` is non-nil (throws `SwiftSynapseError.clientNotInjected`)
2. Sets status to `.running`
3. Calls `client.chat(model:message:)`
4. Extracts text content from assistant response
5. Appends user and assistant `TranscriptEntry` to transcript
6. Sets status to `.completed` and returns result
7. On error: sets status to `.failed` and rethrows

### Example

```swift
@SpecDrivenAgent
actor MyAgent {
    // All members above are generated automatically
}
```

## @StructuredOutput

Generates a `textFormat` static property on a `struct` declaration.

### Target Type

`struct` only. Applying to any other declaration kind emits:

> error: @StructuredOutput can only be applied to a struct

### Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `textFormat` | static computed property | `TextFormat` | internal |

The generated property returns `.jsonSchema(name: "<TypeName>", schema: Self.jsonSchema, strict: true)`, where `<TypeName>` is the struct's name extracted at compile time.

### Prerequisites

The struct must have a `jsonSchema` static property, typically provided by `@LLMToolArguments` conformance from SwiftLLMToolMacros.

### Example

```swift
@StructuredOutput
struct SearchResult {
    // Requires @LLMToolArguments conformance for Self.jsonSchema
    // Generates: static var textFormat: TextFormat
}
```

## @Capability

Generates an `agentTools()` method on a `struct` or `class` declaration.

### Target Type

`struct` or `class`. Applying to any other declaration kind (enum, actor, etc.) emits:

> error: @Capability can only be applied to a struct or class

### Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `agentTools()` | method | `() -> [AgentTool]` | internal |

### Current Implementation

Returns an empty array. Future versions will introspect `@LLMTool`-conforming properties and bridge them automatically.

### Example

```swift
@Capability
struct WebSearch {
    // Generates: func agentTools() -> [AgentTool]
}
```

## Diagnostics Summary

| Macro | Diagnostic ID | Message |
|-------|--------------|---------|
| `@SpecDrivenAgent` | `requiresActor` | `@SpecDrivenAgent can only be applied to an actor` |
| `@StructuredOutput` | `requiresStruct` | `@StructuredOutput can only be applied to a struct` |
| `@Capability` | `requiresStructOrClass` | `@Capability can only be applied to a struct or class` |
