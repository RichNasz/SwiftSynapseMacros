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
| [Client-Types.md](Client-Types.md) | `Sources/SwiftSynapseMacrosClient/AgentTool.swift`, `TextFormat.swift`, `SwiftSynapseError.swift`, `Transcript.swift`, `AgentStatus.swift`, `AgentRuntime.swift`, `AgentGoalMetadata.swift`, `Macros.swift` |
| [Client-AgentHarness.md](Client-AgentHarness.md) | `AgentToolProtocol.swift`, `ToolRegistry.swift`, `AgentToolLoop.swift`, `StreamingToolExecutor.swift`, `AgentHook.swift`, `AgentHookPipeline.swift`, `Permission.swift`, `ToolListPolicy.swift`, `AgentLLMClient.swift`, `AgentConfiguration.swift`, `AgentSession.swift`, `RetryWithBackoff.swift`, `RecoveryStrategy.swift`, `ContextBudget.swift`, `Telemetry.swift`, `TelemetrySinks.swift`, `SubagentContext.swift` |
| [Client-Production.md](Client-Production.md) | `SessionPersistence.swift`, `Guardrails.swift`, `ToolProgress.swift`, `MCP.swift`, `ContextCompression.swift`, `ConfigurationHierarchy.swift`, `Caching.swift`, `DenialTracking.swift`, `AgentCoordination.swift`, `PluginSystem.swift` |
| [Tests.md](Tests.md) | `Tests/SwiftSynapseMacrosTests/MacroExpansionTests.swift` |
| [README-Generation.md](README-Generation.md) | `README.md` (root) |

## Infrastructure Files

| File | Spec Source |
|------|-------------|
| `Sources/SwiftSynapseMacros/Plugin.swift` | This file (`Overview.md`) — plugin registration |

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
