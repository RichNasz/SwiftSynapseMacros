# Spec: Macro Expansion Tests

**Generates:**
- `Tests/SwiftSynapseMacrosTests/MacroExpansionTests.swift`
- `Tests/SwiftSynapseMacrosTests/AgentGoalMacroTests.swift`

## Overview

Tests use `assertMacroExpansion` from `SwiftSyntaxMacrosTestSupport` to verify that each macro produces the expected code and diagnostics.

## Test Infrastructure

```swift
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwiftSynapseMacros)
import SwiftSynapseMacros

let testMacros: [String: Macro.Type] = [
    "SpecDrivenAgent": SpecDrivenAgentMacro.self,
    "StructuredOutput": StructuredOutputMacro.self,
    "Capability": CapabilityMacro.self,
]
#endif
```

All test methods are wrapped in `#if canImport(SwiftSynapseMacros)` with a fallback `testMacrosNotAvailable()` that calls `XCTFail`.

## Test Cases

### @SpecDrivenAgent

| Test | Input | Expected |
|------|-------|----------|
| `testSpecDrivenAgentExpandsOnActor` | `@SpecDrivenAgent actor MyAgent {}` | All generated members (`_status`, `_transcript`, `_client`, `status`, `transcript`, `client`, `configure`, `run`) |
| `testSpecDrivenAgentDiagnosesStruct` | `@SpecDrivenAgent struct NotAnActor {}` | No expansion, diagnostic: `"@SpecDrivenAgent can only be applied to an actor"` at line 1, column 1 |
| `testSpecDrivenAgentDiagnosesClass` | `@SpecDrivenAgent class NotAnActor {}` | No expansion, diagnostic: `"@SpecDrivenAgent can only be applied to an actor"` at line 1, column 1 |
| `testSpecDrivenAgentUsesActorName` | `@SpecDrivenAgent actor CustomBot {}` | All generated members (verifies expansion works with different actor names) |

**Note:** SwiftSyntax reformats single-line closures to multi-line in expansion output. The expected expansion strings must account for this formatting.

### @StructuredOutput

| Test | Input | Expected |
|------|-------|----------|
| `testStructuredOutputExpandsOnStruct` | `@StructuredOutput struct Response {}` | `static var textFormat: TextFormat { .jsonSchema(name: "Response", schema: Self.jsonSchema, strict: true) }` |
| `testStructuredOutputDiagnosesClass` | `@StructuredOutput class NotAStruct {}` | No expansion, diagnostic: `"@StructuredOutput can only be applied to a struct"` at line 1, column 1 |
| `testStructuredOutputDiagnosesEnum` | `@StructuredOutput enum NotAStruct {}` | No expansion, diagnostic: `"@StructuredOutput can only be applied to a struct"` at line 1, column 1 |

### @Capability

| Test | Input | Expected |
|------|-------|----------|
| `testCapabilityExpandsOnStruct` | `@Capability struct Tools {}` | `func agentTools() -> [AgentTool] { [] }` with TODO comment |
| `testCapabilityExpandsOnClass` | `@Capability class Tools {}` | `func agentTools() -> [AgentTool] { [] }` with TODO comment |
| `testCapabilityDiagnosesActor` | `@Capability actor Foo {}` | No expansion, diagnostic: `"@Capability can only be applied to a struct or class"` at line 1, column 1 |
| `testCapabilityDiagnosesEnum` | `@Capability enum Foo {}` | No expansion, diagnostic: `"@Capability can only be applied to a struct or class"` at line 1, column 1 |

### @AgentGoal

`@AgentGoal` tests live in a separate file (`AgentGoalMacroTests.swift`) with their own macro dictionary since `@AgentGoal` is a `PeerMacro` (not a `MemberMacro` like the others).

| Test | Input | Expected |
|------|-------|----------|
| `testAgentGoalExpandsOnStaticLet` | `@AgentGoal static let goal = "Think step-by-step. Use tools when needed."` | Generates `goal_metadata: AgentGoalMetadata` with default parameters |
| `testAgentGoalWithParameters` | `@AgentGoal(maxTurns: 10, temperature: 0.5) static let goal = "Think step-by-step."` | Generates metadata with custom maxTurns and temperature |
| `testAgentGoalDiagnosesEmptyPrompt` | `@AgentGoal static let goal = ""` | No expansion, diagnostic: `"Agent goal cannot be empty"` at line 2, column 19 |
| `testAgentGoalDiagnosesNonStaticLet` | `@AgentGoal var goal = "Think step-by-step."` | No expansion, diagnostic: `"@AgentGoal can only be applied to a static let declaration"` at line 1, column 1 |
| `testAgentGoalWarnsOnMissingAgenticKeywords` | `@AgentGoal static let goal = "Hello world"` | Generates metadata, warning: `"Goal may not encourage agentic behavior — consider adding 'think step-by-step' or 'use tools'"` at line 2, column 19 |
| `testAgentGoalDiagnosesInvalidMaxTurns` | `@AgentGoal(maxTurns: 0) static let goal = "Think step-by-step."` | No expansion, diagnostic: `"maxTurns must be at least 1"` at line 1, column 1 |
| `testAgentGoalDiagnosesInvalidTemperature` | `@AgentGoal(temperature: 3.0) static let goal = "Think step-by-step."` | No expansion, diagnostic: `"temperature must be between 0 and 2"` at line 1, column 1 |

## Expansion Verification Notes

- The `expandedSource` must match the exact formatting that SwiftSyntax produces
- Single-line closures in macro source get reformatted to multi-line in expansion
- Each generated member appears with a blank line separator in the expanded output
