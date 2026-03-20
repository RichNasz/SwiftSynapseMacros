# Spec: @StructuredOutput Macro

**Generates:** `Sources/SwiftSynapseMacros/StructuredOutputMacro.swift`

## Purpose

Attach to a `struct` declaration to generate a `textFormat` static property that bridges the struct's `jsonSchema` (from `@LLMToolArguments` conformance) to `TextFormat`.

## Macro Declaration

```swift
@attached(member, names: named(textFormat))
public macro StructuredOutput() = #externalMacro(module: "SwiftSynapseMacros", type: "StructuredOutputMacro")
```

## Target Type

`struct` only. Emits a diagnostic error if applied to any other declaration kind.

## Generated Members

| Member | Kind | Type | Access | Description |
|--------|------|------|--------|-------------|
| `textFormat` | static computed property | `TextFormat` | internal | Returns `.jsonSchema(name: "<TypeName>", schema: Self.jsonSchema, strict: true)` |

The `<TypeName>` is extracted from the struct declaration's name at compile time using `structDecl.name.trimmedDescription`.

## Dependencies (Referenced Types)

- `TextFormat` — from `SwiftSynapseMacrosClient`
- `Self.jsonSchema` — expected to be provided by `@LLMToolArguments` conformance (from `SwiftLLMToolMacros`)

## Diagnostic

| ID | Severity | Message | Condition |
|----|----------|---------|-----------|
| `requiresStruct` | error | `@StructuredOutput can only be applied to a struct` | Declaration is not `StructDeclSyntax` |

## Implementation Structure

```swift
public struct StructuredOutputMacro: MemberMacro { ... }
enum StructuredOutputDiagnostic: String, DiagnosticMessage { ... }
```
