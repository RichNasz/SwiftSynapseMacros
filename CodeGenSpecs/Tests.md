# Spec: Macro Expansion Tests

**Generates:** `Tests/SwiftSynapseMacrosTests/MacroExpansionTests.swift`

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
| `testSpecDrivenAgentExpandsOnActor` | `@SpecDrivenAgent actor MyAgent {}` | All generated members (Status enum, properties, run method) |
| `testSpecDrivenAgentDiagnosesStruct` | `@SpecDrivenAgent struct NotAnActor {}` | No expansion, diagnostic: `"@SpecDrivenAgent can only be applied to an actor"` at line 1, column 1 |
| `testSpecDrivenAgentDiagnosesClass` | `@SpecDrivenAgent class NotAnActor {}` | No expansion, diagnostic: `"@SpecDrivenAgent can only be applied to an actor"` at line 1, column 1 |
| `testSpecDrivenAgentUsesActorName` | `@SpecDrivenAgent actor CustomBot {}` | All generated members use "CustomBot" naming (verifies name isn't hardcoded) |

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

## Expansion Verification Notes

- The `expandedSource` must match the exact formatting that SwiftSyntax produces
- Single-line closures in macro source get reformatted to multi-line in expansion
- Each generated member appears with a blank line separator in the expanded output
