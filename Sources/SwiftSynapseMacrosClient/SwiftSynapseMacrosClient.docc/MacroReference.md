<!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->

# Macro Reference

An overview of all four SwiftSynapseMacros macros, with links to detailed reference and how-to articles for each.

## Overview

SwiftSynapseMacros provides four macros. `@SpecDrivenAgent` is the primary one — it's applied to every agent actor. The others are additive: use them when your agent needs tools, structured output, or compile-time validated goals.

| Macro | Applied to | Generates |
|-------|-----------|-----------|
| `@SpecDrivenAgent` | `actor` | `run(goal:)`, `status`, `transcript`, `AgentExecutable` conformance |
| `@Capability` | `struct` or `class` | `agentTools() -> [AgentTool]` |
| `@StructuredOutput` | `struct` | `static var textFormat: TextFormat` |
| `#AgentGoal` | string literal | `AgentGoalMetadata` companion value |

## @SpecDrivenAgent

The primary macro. Generates lifecycle scaffolding on an `actor` — stored properties, computed accessors, and `run(goal:)`. You implement `execute(goal:)` with domain logic; the macro handles everything else: goal validation, status transitions, transcript reset, hook firing, and error surfacing.

→ See <doc:SpecDrivenAgent> for the full reference.
→ See <doc:HowTo-SpecDrivenAgent> for practical usage examples.

## @Capability

Groups related `@LLMTool`-annotated methods into a single type. Generates `agentTools() -> [AgentTool]` so the methods can be registered with a `ToolRegistry` in a single call. Apply `@Capability` to any `struct` or `class` whose methods are your agent's tools.

→ See <doc:Capability> for the full reference.
→ See <doc:HowTo-Capability> for practical usage examples.

## @StructuredOutput

Generates `static var textFormat: TextFormat` on a `struct`, packaging the struct's JSON schema (from `@LLMToolArguments`) into the format the LLM client uses to request structured output. Pair with `@LLMToolArguments` and `Codable` for a complete structured response type.

→ See <doc:StructuredOutput> for the full reference.
→ See <doc:HowTo-StructuredOutput> for practical usage examples.

## #AgentGoal

A freestanding macro applied to string literals. Validates the prompt at compile time (empty check, parameter bounds) and generates a companion `AgentGoalMetadata` value that carries per-goal LLM configuration (`maxTurns`, `temperature`, `requiresTools`, `preferredFormat`).

→ See <doc:AgentGoal> for the full reference.
→ See <doc:HowTo-AgentGoal> for practical usage examples.

## Diagnostics Summary

| Macro | Error ID | Message |
|-------|----------|---------|
| `@SpecDrivenAgent` | `requiresActor` | `@SpecDrivenAgent can only be applied to an actor` |
| `@StructuredOutput` | `requiresStruct` | `@StructuredOutput can only be applied to a struct` |
| `@Capability` | `requiresStructOrClass` | `@Capability can only be applied to a struct or class` |
| `#AgentGoal` | `emptyGoal` | `Goal prompt cannot be empty` |
| `#AgentGoal` | `invalidMaxTurns` | `maxTurns must be at least 1` |
| `#AgentGoal` | `invalidTemperature` | `temperature must be between 0 and 2` |

## Topics

### Individual Macro Reference
- <doc:SpecDrivenAgent>
- <doc:Capability>
- <doc:StructuredOutput>
- <doc:AgentGoal>

### How-To Guides
- <doc:HowTo-SpecDrivenAgent>
- <doc:HowTo-Capability>
- <doc:HowTo-StructuredOutput>
- <doc:HowTo-AgentGoal>
- <doc:HowTo-CombiningMacros>
