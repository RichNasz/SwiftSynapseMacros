# Spec: Client Types

**Generates:**
- `Sources/SwiftSynapseMacrosClient/TranscriptEntry.swift`
- `Sources/SwiftSynapseMacrosClient/AgentTool.swift`
- `Sources/SwiftSynapseMacrosClient/TextFormat.swift`
- `Sources/SwiftSynapseMacrosClient/SwiftSynapseError.swift`
- `Sources/SwiftSynapseMacrosClient/Transcript.swift`
- `Sources/SwiftSynapseMacrosClient/Macros.swift`

## Overview

The client target (`SwiftSynapseMacrosClient`) provides:
1. `#externalMacro` declarations for all macros
2. Re-exports of sibling packages via `@_exported import`
3. Orchestration types used by generated macro code

---

## TranscriptEntry

A simple value type wrapping a conversation role and content string.

```swift
import SwiftResponsesDSL

public struct TranscriptEntry: Sendable {
    public let role: Role        // from SwiftResponsesDSL
    public let content: String

    public init(role: Role, content: String)
}
```

**Dependencies:** `Role` from `SwiftResponsesDSL`

---

## AgentTool

Wraps a `ToolDefinition` and provides convenience initialization from any `LLMTool` type.

```swift
import SwiftLLMToolMacros

public struct AgentTool: Sendable {
    public let definition: ToolDefinition

    public init(definition: ToolDefinition)
    public init<T: LLMTool>(_ tool: T.Type)  // bridges via T.toolDefinition
}
```

**Dependencies:** `ToolDefinition`, `LLMTool` from `SwiftLLMToolMacros`

---

## TextFormat

Enum representing the output format for structured responses.

```swift
import SwiftLLMToolMacros

public enum TextFormat: Sendable {
    case jsonSchema(name: String, schema: JSONSchemaValue, strict: Bool)
    case text
}
```

**Dependencies:** `JSONSchemaValue` from `SwiftLLMToolMacros`

---

## SwiftSynapseError

Error type for agent orchestration failures.

```swift
public enum SwiftSynapseError: Error, Sendable {
    case agentNotConfigured    // Agent spec or configuration missing
    case clientNotInjected     // LLMClient not set before calling run()
}
```

**Dependencies:** None (stdlib only)

---

## ObservableTranscript

`@Observable` class for SwiftUI binding of agent conversation state.

```swift
import Observation

@Observable
public final class ObservableTranscript {
    public private(set) var entries: [TranscriptEntry] = []
    public private(set) var isStreaming: Bool = false
    public private(set) var streamingText: String = ""

    public init()

    public func sync(from transcript: [TranscriptEntry])
    public func append(_ entry: TranscriptEntry)
    public func setStreaming(_ streaming: Bool)
    public func appendDelta(_ text: String)
    public func reset()
}
```

### Method Behavior

| Method | Behavior |
|--------|----------|
| `sync(from:)` | Replaces `entries` with provided array |
| `append(_:)` | Appends a single entry |
| `setStreaming(_:)` | Sets streaming flag; clears `streamingText` when `false` |
| `appendDelta(_:)` | Appends text to `streamingText` |
| `reset()` | Clears all state to initial values |

**Dependencies:** `Observation` framework, `TranscriptEntry`

---

## Macros.swift

Contains `#externalMacro` declarations and re-exports.

```swift
@_exported import SwiftLLMToolMacros
@_exported import SwiftResponsesDSL

@attached(member, names: ...) public macro SpecDrivenAgent() = #externalMacro(...)
@attached(member, names: ...) public macro StructuredOutput() = #externalMacro(...)
@attached(member, names: ...) public macro Capability() = #externalMacro(...)
```

See individual macro specs for exact `names:` lists and documentation comments.
