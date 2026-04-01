# SwiftSynapseMacros

## Project Overview

SwiftSynapseMacros provides Swift macros and core types for the SwiftSynapse ecosystem. It generates agent scaffolding (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`) and provides foundational types used by macro-generated code and SwiftUI views.

The agent harness (tool loop, hooks, permissions, streaming, recovery, MCP, etc.) lives in [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness).

## Commands

- **Build**: `swift build`
- **Test**: `swift test`
- **Test (verbose)**: `swift test --verbose`
- **Clean**: `swift package clean`

## Architecture

### Three-Target Structure

1. **SwiftSynapseMacros** (macro target) - Compiler plugin
   - `Plugin.swift` - `@main` CompilerPlugin entry point
   - `SpecDrivenAgentMacro.swift` - Agent scaffold generation
   - `StructuredOutputMacro.swift` - JSON schema bridging
   - `CapabilityMacro.swift` - Tool bridging
   - `AgentGoalMacro.swift` - Goal validation and metadata generation
   - **SwiftSyntax only** — no sibling package imports

2. **SwiftSynapseMacrosClient** (client target) - Core types + macro declarations
   - `Macros.swift` - `#externalMacro` declarations + `@_exported import` of siblings
   - `AgentExecutable.swift` - Protocol for @SpecDrivenAgent actors + AgentLifecycleError
   - `AgentStatus.swift` - Shared agent status enum
   - `Transcript.swift` - `@Observable` transcript for SwiftUI
   - `TextFormat.swift` - Output format enum
   - `AgentGoalMetadata.swift` - Goal metadata struct
   - `ToolProgressUpdate.swift` - Tool progress data type
   - `AgentTool.swift` - Deprecated tool bridging type

3. **SwiftSynapseMacrosTests** (test target)
   - XCTest-based macro expansion tests (`assertMacroExpansion`)

### Key Design Decisions

- **Macro target is SwiftSyntax-only**: The compiler plugin cannot import sibling packages.
- **Client re-exports siblings**: `@_exported import SwiftLLMToolMacros` and `@_exported import SwiftOpenResponsesDSL`.
- **Harness is separate**: The agent runtime (`agentRun()`), tool loop, hooks, and all production capabilities live in SwiftSynapseHarness. Users typically `import SwiftSynapseHarness` which re-exports this package.
- **Actor-only agents**: `@SpecDrivenAgent` enforces `actor` declarations at compile time.

## Spec-Driven Workflow

All `.swift` files in `Sources/` and `Tests/` are generated from specs in `CodeGenSpecs/`. Specs are the single source of truth.

1. Edit the relevant spec in `CodeGenSpecs/`
2. Re-generate the corresponding `.swift` file(s)
3. Run `swift build && swift test` to verify
4. Commit both spec and generated files together

**Never edit generated `.swift` files directly.**

## File Structure

```
Sources/
  SwiftSynapseMacros/                # Compiler plugin (SwiftSyntax only)
    Plugin.swift
    SpecDrivenAgentMacro.swift
    StructuredOutputMacro.swift
    CapabilityMacro.swift
    AgentGoalMacro.swift
  SwiftSynapseMacrosClient/         # Core types + macro declarations
    Macros.swift
    AgentExecutable.swift
    AgentStatus.swift
    Transcript.swift
    TextFormat.swift
    AgentGoalMetadata.swift
    ToolProgressUpdate.swift
    AgentTool.swift
Tests/
  SwiftSynapseMacrosTests/
    MacroExpansionTests.swift
    AgentGoalMacroTests.swift
CodeGenSpecs/
  Overview.md
  Macros-SpecDrivenAgent.md
  Macros-StructuredOutput.md
  Macros-Capability.md
  Macros-AgentGoal.md
  Client-Types.md
  Tests.md
  README-Generation.md
```

## Dependencies

- [swift-syntax](https://github.com/swiftlang/swift-syntax) >= 602.0.0
- [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) (branch: main)
- [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) (branch: main)

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Testing Strategy

- **Macro expansion tests** use `assertMacroExpansion` from SwiftSyntaxMacrosTestSupport (XCTest)
- Tests cover: correct member/peer generation, diagnostic errors for wrong declaration kinds, compile-time validation

## Claude Code Files

Only `CLAUDE.md` is tracked. The `.claude/` directory is gitignored.
