# SwiftSynapseMacros

## Project Overview

SwiftSynapseMacros is the macro-powered orchestration layer for the SwiftSynapse ecosystem. It provides Swift macros (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`) that generate boilerplate for LLM agent orchestration, bridging SwiftOpenResponsesDSL's LLM client and SwiftLLMToolMacros' tool definitions into observable, status-tracked agent actors.

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
   - **SwiftSyntax only** — no sibling package imports

2. **SwiftSynapseMacrosClient** (client target) - Public API that users import
   - `Macros.swift` - `#externalMacro` declarations + `@_exported import` of siblings
   - `TranscriptEntry.swift` - Role + content conversation wrapper
   - `AgentTool.swift` - Bridges `ToolDefinition` / `LLMTool`
   - `TextFormat.swift` - `.jsonSchema` / `.text` output format enum
   - `SwiftSynapseError.swift` - Error cases for orchestration
   - `Transcript.swift` - `@Observable` transcript for SwiftUI

3. **SwiftSynapseMacrosTests** (test target)
   - XCTest-based macro expansion tests (`assertMacroExpansion`)

### Key Design Decisions

- **Macro target is SwiftSyntax-only**: The compiler plugin cannot import sibling packages. It generates code strings that reference types from the client target.
- **Client re-exports siblings**: `@_exported import SwiftLLMToolMacros` and `@_exported import SwiftOpenResponsesDSL` so consumers only need to import `SwiftSynapseMacrosClient`.
- **Diagnostics**: Each macro has a diagnostic enum conforming to `SwiftDiagnostics.DiagnosticMessage`.
- **Actor-only agents**: `@SpecDrivenAgent` enforces `actor` declarations at compile time.

## Spec-Driven Workflow

All `.swift` files in `Sources/` and `Tests/` are generated from specs in `CodeGenSpecs/`. Specs are the single source of truth.

1. Edit the relevant spec in `CodeGenSpecs/`
2. Re-generate the corresponding `.swift` file(s)
3. Run `swift build && swift test` to verify
4. Commit both spec and generated files together

**Never edit generated `.swift` files directly.** Every generated file has a header comment pointing to its source spec.

## File Structure

```
Sources/
  SwiftSynapseMacros/                # Compiler plugin (SwiftSyntax only)
    Plugin.swift                     # @main entry point
    SpecDrivenAgentMacro.swift       # @SpecDrivenAgent implementation
    StructuredOutputMacro.swift      # @StructuredOutput implementation
    CapabilityMacro.swift            # @Capability implementation
  SwiftSynapseMacrosClient/         # Public API
    Macros.swift                     # #externalMacro declarations + re-exports
    TranscriptEntry.swift            # Role + content wrapper
    AgentTool.swift                  # Tool bridging type
    TextFormat.swift                 # Output format enum
    SwiftSynapseError.swift          # Error type
    Transcript.swift                 # ObservableTranscript
Tests/
  SwiftSynapseMacrosTests/
    MacroExpansionTests.swift        # assertMacroExpansion tests
CodeGenSpecs/                        # Source of truth
  Overview.md                        # Spec index and rules
  Macros-SpecDrivenAgent.md          # @SpecDrivenAgent spec
  Macros-StructuredOutput.md         # @StructuredOutput spec
  Macros-Capability.md               # @Capability spec
  Client-Types.md                    # Client type specs
  Tests.md                           # Test spec
  README-Generation.md               # README spec
Examples/                            # Excluded from build
```

## Type References

Types referenced in macro-generated code come from different packages:

| Type | Source Package |
|------|---------------|
| `TranscriptEntry` | SwiftSynapseMacrosClient |
| `AgentTool` | SwiftSynapseMacrosClient |
| `TextFormat` | SwiftSynapseMacrosClient |
| `SwiftSynapseError` | SwiftSynapseMacrosClient |
| `ObservableTranscript` | SwiftSynapseMacrosClient |
| `LLMClient` | SwiftOpenResponsesDSL (re-exported) |
| `Role` | SwiftOpenResponsesDSL (re-exported) |
| `ToolDefinition` | SwiftLLMToolMacros (re-exported) |
| `LLMTool` | SwiftLLMToolMacros (re-exported) |
| `JSONSchemaValue` | SwiftLLMToolMacros (re-exported) |

## Dependencies

- [swift-syntax](https://github.com/swiftlang/swift-syntax) >= 602.0.0
- [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) (branch: main)
- [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) (branch: main)

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Testing Strategy

- **Macro expansion tests** use `assertMacroExpansion` from SwiftSyntaxMacrosTestSupport (XCTest)
- SwiftSyntax reformats single-line closures to multi-line in expansion tests — expected behavior
- Tests cover: correct member generation, diagnostic errors for wrong declaration kinds

## Claude Code Files

Only the following Claude-related files are tracked:

- **`CLAUDE.md`** — Project instructions loaded automatically by Claude Code

The `.claude/` directory is gitignored and must never be committed.
