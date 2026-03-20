# Spec: @SpecDrivenAgent Macro

**Generates:** `Sources/SwiftSynapseMacros/SpecDrivenAgentMacro.swift`

## Purpose

Attach to an `actor` declaration to generate a complete agent scaffold with status tracking, LLM client wrapper, and conversation transcript.

## Macro Declaration

```swift
@attached(member, names: named(Status), named(_status), named(_transcript),
          named(status), named(isRunning), named(transcript), named(client))
public macro SpecDrivenAgent() = #externalMacro(module: "SwiftSynapseMacros", type: "SpecDrivenAgentMacro")
```

## Target Type

`actor` only. Emits a diagnostic error if applied to any other declaration kind.

## Generated Members

| Member | Kind | Type | Access | Description |
|--------|------|------|--------|-------------|
| `Status` | enum | `String, Sendable` | internal | Cases: `idle`, `running`, `completed`, `failed` |
| `_status` | stored property | `Status` | `private` | Initial value: `.idle` |
| `_transcript` | stored property | `[TranscriptEntry]` | `private` | Initial value: `[]` |
| `status` | computed property | `Status` | internal | Returns `_status` |
| `isRunning` | computed property | `Bool` | internal | Returns `_status == .running` |
| `transcript` | computed property | `[TranscriptEntry]` | internal | Returns `_transcript` |
| `client` | stored property | `LLMClient?` | internal | Injected client |

## Dependencies (Referenced Types)

- `TranscriptEntry` — from `SwiftOpenResponsesDSL` (re-exported by client)
- `LLMClient` — from `SwiftOpenResponsesDSL` (re-exported by client)

## Diagnostic

| ID | Severity | Message | Condition |
|----|----------|---------|-----------|
| `requiresActor` | error | `@SpecDrivenAgent can only be applied to an actor` | Declaration is not `ActorDeclSyntax` |

## Implementation Structure

```swift
public struct SpecDrivenAgentMacro: MemberMacro { ... }
enum SpecDrivenAgentDiagnostic: String, DiagnosticMessage { ... }
```
