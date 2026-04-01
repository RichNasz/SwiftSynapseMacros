# CodeGenSpecs Overview

## Purpose

This directory contains the specifications that serve as the single source of truth for all generated `.swift` files in SwiftSynapseMacros. Every `.swift` file in `Sources/` and `Tests/` is a generated artifact — to change behavior, update the relevant spec and re-generate.

## Spec Files

| Spec | Generates |
|------|-----------|
| [Macros-SpecDrivenAgent.md](Macros-SpecDrivenAgent.md) | `Sources/SwiftSynapseMacros/SpecDrivenAgentMacro.swift` |
| [Macros-StructuredOutput.md](Macros-StructuredOutput.md) | `Sources/SwiftSynapseMacros/StructuredOutputMacro.swift` |
| [Macros-Capability.md](Macros-Capability.md) | `Sources/SwiftSynapseMacros/CapabilityMacro.swift` |
| [Macros-AgentGoal.md](Macros-AgentGoal.md) | `Sources/SwiftSynapseMacros/AgentGoalMacro.swift` |
| [Client-Types.md](Client-Types.md) | `Sources/SwiftSynapseMacrosClient/AgentTool.swift`, `TextFormat.swift`, `Transcript.swift`, `AgentStatus.swift`, `AgentExecutable.swift`, `AgentGoalMetadata.swift`, `ToolProgressUpdate.swift`, `Macros.swift` |
| [Tests.md](Tests.md) | `Tests/SwiftSynapseMacrosTests/MacroExpansionTests.swift` |
| [README-Generation.md](README-Generation.md) | `README.md` (root) |

## SwiftSynapseUI

SwiftSynapseUI (drop-in agent views) has moved to [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) (`CodeGenSpecs/UI.md`). Import `SwiftSynapseUI` from the `SwiftSynapseHarness` package.

## Infrastructure Files

| File | Spec Source |
|------|-------------|
| `Sources/SwiftSynapseMacros/Plugin.swift` | This file (`Overview.md`) — plugin registration |

## Harness Specs

Agent harness specifications live in the [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) package:

| Spec | Content |
|------|---------|
| `Client-Runtime.md` | AgentRuntime, agentRun(), ObservableTranscript+Harness |
| `Client-AgentHarness.md` | Tool system, hooks, permissions, streaming, recovery, telemetry |
| `Client-Production.md` | Session persistence, guardrails, MCP, compression, caching, coordination, plugins |
| `Client-ProductionPolish.md` | Cost tracking, error classification, rate limiting, VCR testing, shutdown, memory, conversation recovery |

## Generation Rules

1. Every generated `.swift` file starts with a header comment:
   ```
   // Generated from CodeGenSpecs/<SpecName>.md — Do not edit manually. Update spec and re-generate.
   ```

2. The `Plugin.swift` file registers all macros listed across the `Macros-*.md` specs.

3. The `Macros.swift` client file declares `#externalMacro` entries for every macro in the plugin.

4. Specs are the authority — if code and spec disagree, the spec wins.

## Workflow

1. Edit the relevant spec in `CodeGenSpecs/`
2. Re-generate the corresponding `.swift` file(s)
3. Run `swift build` and `swift test` to verify
4. Commit both spec and generated files together
