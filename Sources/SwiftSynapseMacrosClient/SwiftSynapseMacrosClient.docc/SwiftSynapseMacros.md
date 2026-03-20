# ``SwiftSynapseMacrosClient``

@Metadata {
    @DisplayName("SwiftSynapseMacros")
    @PageKind(sampleCode)
    @CallToAction(
        purpose: link,
        label: "View on GitHub",
        url: "https://github.com/RichNasz/SwiftSynapseMacros"
    )
}

Macro-powered orchestration layer for SwiftSynapse agents.

## Overview

SwiftSynapseMacros provides Swift macros that generate boilerplate for LLM agent orchestration. It bridges SwiftOpenResponsesDSL's LLM client and SwiftLLMToolMacros' tool definitions into observable, status-tracked agent actors.

- **Status Tracking**: `@SpecDrivenAgent` generates a `Status` enum and observable state for every agent actor
- **Transcript Observability**: Agents automatically accumulate `[TranscriptEntry]` conversation history, with `ObservableTranscript` for SwiftUI
- **Tool Bridging**: `@Capability` bridges `@LLMTool`-annotated types into `[AgentTool]`
- **Structured Output**: `@StructuredOutput` connects `@LLMToolArguments` JSON schemas to the `TextFormat` type

## Quick Start

Add SwiftSynapseMacros to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
]
```

Then import `SwiftSynapseMacrosClient` in your target:

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
actor MyAgent {
    // Generates: Status enum, status tracking, transcript,
    // LLMClient wrapper, and run(_:) method
}
```

## Topics

### Essentials
- <doc:GettingStarted>
- <doc:MacroReference>
- <doc:IntegrationGuide>

### Macros
- ``SpecDrivenAgent()``
- ``StructuredOutput()``
- ``Capability()``

### Orchestration Types
- ``AgentTool``
- ``TextFormat``
- ``SwiftSynapseError``
- ``ObservableTranscript``
