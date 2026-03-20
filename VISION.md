# SwiftSynapseMacros Vision

## Overview

SwiftSynapseMacros is the macro-powered orchestration layer for the SwiftSynapse ecosystem. It provides Swift macros (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`) that generate boilerplate for agent orchestration, bridging SwiftResponsesDSL's LLM client and SwiftLLMToolMacros' tool definitions into a cohesive, observable agent architecture.

## Core Goals

1. **Status Tracking** — Every agent gets a generated `Status` enum and observable state, enabling UI binding and lifecycle management without manual boilerplate.
2. **Transcript Observability** — Agents automatically accumulate conversation history as `[TranscriptEntry]`, with an `ObservableTranscript` class for SwiftUI integration.
3. **Tool Bridging** — `@Capability` bridges `@LLMTool`-annotated types into `[AgentTool]`, unifying the tool system across packages.
4. **Structured Output** — `@StructuredOutput` connects `@LLMToolArguments`' JSON schema generation to the `TextFormat` type used by the DSL layer.

## Non-Negotiables

- **Swift 6.2+** — Uses modern Swift concurrency, actors, and macro system.
- **Spec-Driven** — All `.swift` files are generated from specs in `CodeGenSpecs/`. Generated files are never manually edited.
- **No Manual Edits** — Every generated file carries a header comment pointing to its source spec.
- **Compile-Time Safety** — Macros emit diagnostics for misuse (e.g., `@SpecDrivenAgent` on a struct).

## Dependencies

| Package | Purpose |
|---------|---------|
| `swift-syntax` 602.0.0+ | SwiftSyntax for macro implementation |
| `SwiftLLMToolMacros` (branch: main) | `LLMTool`, `LLMToolArguments`, `ToolDefinition`, `JSONSchemaValue` |
| `SwiftResponsesDSL` (branch: main) | `LLMClient`, `Response`, `Role`, message types |

## Platforms

- macOS 26+
- iOS 26+
- visionOS 2+

## Package Structure

```
SwiftSynapseMacros/          # Macro target (compiler plugin, SwiftSyntax only)
SwiftSynapseMacrosClient/    # Client target (#externalMacro declarations, orchestration types)
SwiftSynapseMacrosTests/     # Macro expansion tests
CodeGenSpecs/                # Spec files (source of truth)
```
