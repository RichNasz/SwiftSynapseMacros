# Spec: @Capability Macro

**Generates:** `Sources/SwiftSynapseMacros/CapabilityMacro.swift`

## Purpose

Attach to a `struct` or `class` declaration to generate an `agentTools()` method that bridges `@LLMTool`-annotated types into `[AgentTool]`.

## Macro Declaration

```swift
@attached(member, names: named(agentTools))
public macro Capability() = #externalMacro(module: "SwiftSynapseMacros", type: "CapabilityMacro")
```

## Target Type

`struct` or `class`. Emits a diagnostic error if applied to any other declaration kind (e.g., `enum`, `actor`).

## Generated Members

| Member | Kind | Type | Access | Description |
|--------|------|------|--------|-------------|
| `agentTools()` | method | `() -> [AgentTool]` | internal | Returns an array of `AgentTool` instances bridged from `@LLMTool` types |

### Current Implementation

Returns an empty array with a `// TODO` comment. Future versions will introspect conforming `@LLMTool` properties and bridge them automatically.

```swift
func agentTools() -> [AgentTool] {
    // TODO: bridge @LLMTool types to AgentTool
    []
}
```

## Dependencies (Referenced Types)

- `AgentTool` — from `SwiftSynapseMacrosClient`
- `LLMTool` — from `SwiftLLMToolMacros` (re-exported by client)

## Diagnostic

| ID | Severity | Message | Condition |
|----|----------|---------|-----------|
| `requiresStructOrClass` | error | `@Capability can only be applied to a struct or class` | Declaration is not `StructDeclSyntax` or `ClassDeclSyntax` |

## Implementation Structure

```swift
public struct CapabilityMacro: MemberMacro { ... }
enum CapabilityDiagnostic: String, DiagnosticMessage { ... }
```
