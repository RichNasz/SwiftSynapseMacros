<!-- Generated from CodeGenSpecs/Docs-Capability.md — Do not edit manually. Update spec and re-generate. -->

# ``Capability()``

@Metadata {
    @DocumentationExtension(mergeBehavior: override)
    @PageKind(symbol)
}

Generates an `agentTools()` method that collects `@LLMTool`-annotated methods into an array for registration with an agent.

## Overview

`@Capability` is applied to a `struct` or `class` that groups related `@LLMTool`-annotated methods. It generates a single instance method — `agentTools() -> [AgentTool]` — that returns all `@LLMTool` methods on the type as an array of `AgentTool` values.

The pattern: define a capability type whose methods are your tools, apply `@Capability`, then call `.agentTools()` when configuring an agent's `ToolRegistry`.

```swift
@Capability
struct MyTools {
    @LLMTool("search", description: "Search the web")
    func search(query: String) async throws -> String { ... }
}

// In execute(goal:):
tools.register(contentsOf: MyTools().agentTools())
```

## Target Declaration

`struct` or `class`. Applying `@Capability` to any other declaration kind is a compile-time error:

```swift
@Capability
actor MyCapability { }
// error: @Capability can only be applied to a struct or class
```

Enum, protocol, and extension applications all emit the same error.

## Generated Members

| Member | Kind | Type | Access |
|--------|------|------|--------|
| `agentTools()` | instance method | `() -> [AgentTool]` | internal |

The generated method collects every `@LLMTool`-annotated method defined on the type. Methods without `@LLMTool` are not included in the returned array.

## Relationship to @LLMTool

`@LLMTool` (from SwiftLLMToolMacros) annotates individual methods with their tool name, description, and parameter schema. `@Capability` discovers `@LLMTool` methods and wraps them. The two macros are designed to be used together — `@Capability` alone (with no `@LLMTool` methods) generates an `agentTools()` that returns an empty array.

## Compile-Time Diagnostics

| ID | Kind | Message |
|----|------|---------|
| `requiresStructOrClass` | error | `@Capability can only be applied to a struct or class` |

## Example

```swift
import SwiftSynapseHarness

@Capability
struct FileSystemTools {
    @LLMTool("readFile", description: "Reads the contents of a file at the given path")
    func readFile(path: String) async throws -> String {
        try String(contentsOfFile: path)
    }

    @LLMTool("listDirectory", description: "Lists files and directories at the given path")
    func listDirectory(path: String) async throws -> String {
        let items = try FileManager.default.contentsOfDirectory(atPath: path)
        return items.joined(separator: "\n")
    }

    // This method has no @LLMTool — it's not included in agentTools()
    private func normalize(path: String) -> String { ... }
}

// In execute(goal:):
@SpecDrivenAgent
actor FileAgent {
    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let tools = ToolRegistry()
        tools.register(contentsOf: FileSystemTools().agentTools())  // 2 tools registered
        return try await AgentToolLoop.run(
            client: client, config: config,
            goal: goal, tools: tools, transcript: _transcript
        )
    }
}
```

### Combining Multiple Capabilities

```swift
let tools = ToolRegistry()
tools.register(contentsOf: FileSystemTools().agentTools())
tools.register(contentsOf: WebSearchTools().agentTools())
// All tools from both capabilities are registered
```

## Topics

### How-To Guides
- <doc:HowTo-Capability>
