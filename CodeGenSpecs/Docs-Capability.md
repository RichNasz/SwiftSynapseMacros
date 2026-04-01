# Spec: @Capability Reference Article

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/Capability.md`

## Purpose

A dedicated DocC reference article for the `@Capability` macro. Readers arrive here wanting to know exactly what it generates and how to get tools from a `@Capability` type into an agent. Keep it focused — this macro generates one method.

## DocC Metadata

```
@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}
```

Targets the `Capability()` macro symbol.

## Article Structure

### Overview (~2–3 sentences)

`@Capability` is applied to a `struct` or `class` that groups related `@LLMTool`-annotated methods. It generates an `agentTools()` method that returns those methods as an `[AgentTool]` array, suitable for passing to `ToolRegistry`. The pattern is: define a capability type whose methods are your tools, apply `@Capability`, then call `.agentTools()` when configuring an agent.

### Target Declaration

`struct` or `class`. Show the error for other types:

```
@Capability
actor MyCapability { }  // error: @Capability can only be applied to a struct or class
```

Enum, protocol, and extension applications all emit the same error.

### Generated Members Table

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `agentTools()` | instance method | `() -> [AgentTool]` | internal |

The generated method collects every `@LLMTool`-annotated method defined on the type and wraps each in an `AgentTool` value. Methods without `@LLMTool` are not included.

### Relationship to @LLMTool

`@LLMTool` (from SwiftLLMToolMacros) annotates individual methods with their name, description, and parameter schema. `@Capability` does not need to know the tool details — it discovers them from the `@LLMTool` annotations already present on the type.

### Compile-Time Diagnostics

| ID | Kind | Message |
|----|------|---------|
| `requiresStructOrClass` | error | `@Capability can only be applied to a struct or class` |

### Full Example

```swift
import SwiftSynapseHarness

@Capability
struct MathTools {
    @LLMTool("calculate", description: "Evaluates a math expression and returns the result")
    func calculate(expression: String) async throws -> String {
        // evaluation logic
    }

    @LLMTool("convert", description: "Converts a value from one unit to another")
    func convert(value: Double, from: String, to: String) async throws -> String {
        // conversion logic
    }
}

// In execute(goal:):
let tools = ToolRegistry()
tools.register(contentsOf: MathTools().agentTools())
```

### Registering Multiple Capabilities

```swift
let tools = ToolRegistry()
tools.register(contentsOf: MathTools().agentTools())
tools.register(contentsOf: WebSearchTools().agentTools())
// All tools from both capabilities are now registered
```

## Tone and Length

Concise reference. Aim for ~200–300 words of prose plus tables and code blocks. Focus on making the `@LLMTool` → `@Capability` → `ToolRegistry` flow obvious.
