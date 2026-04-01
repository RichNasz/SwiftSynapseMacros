<!-- Generated from CodeGenSpecs/Docs-HowTo-Capability.md — Do not edit manually. Update spec and re-generate. -->

# Using @Capability

@Metadata {
    @PageKind(article)
}

How to group tools with `@Capability`, register them with an agent, and compose multiple tool sets.

## Overview

`@Capability` generates an `agentTools()` method on any `struct` or `class` whose methods are annotated with `@LLMTool`. This makes it easy to define, reuse, and compose tool sets. For the generated member reference, see <doc:Capability>.

## Define a Capability with Multiple Tools

Apply `@Capability` to a `struct` and annotate each tool method with `@LLMTool`:

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

    @LLMTool("writeFile", description: "Writes content to a file at the given path")
    func writeFile(path: String, content: String) async throws -> String {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return "Written successfully"
    }

    // No @LLMTool — not included in agentTools()
    private func normalize(path: String) -> String {
        (path as NSString).standardizingPath
    }
}
```

`@Capability` generates `agentTools() -> [AgentTool]` that returns the three `@LLMTool` methods. The private `normalize` method is ignored.

## Register Tools with an Agent

Call `.agentTools()` and pass the result to `ToolRegistry`:

```swift
@SpecDrivenAgent
actor FileAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let tools = ToolRegistry()
        tools.register(contentsOf: FileSystemTools().agentTools())

        return try await AgentToolLoop.run(
            client: client, config: config,
            goal: goal, tools: tools, transcript: _transcript
        )
    }
}
```

The agent now has access to all three file system tools. The LLM sees their names and descriptions and decides when to call each one.

## Combine Multiple Capabilities

Register tools from multiple capability types into a single `ToolRegistry`:

```swift
@Capability
struct WebTools {
    @LLMTool("fetchURL", description: "Fetches the text content of a web page")
    func fetchURL(url: String) async throws -> String { ... }

    @LLMTool("webSearch", description: "Searches the web and returns top results")
    func webSearch(query: String) async throws -> String { ... }
}

// In execute(goal:):
let tools = ToolRegistry()
tools.register(contentsOf: FileSystemTools().agentTools())  // 3 tools
tools.register(contentsOf: WebTools().agentTools())         // 2 tools
// Agent now has 5 tools total
```

This is the primary benefit of `@Capability`: independent, reusable tool groups that compose cleanly.

## Use a Capability with Injected Dependencies

Capabilities can accept dependencies in their initializer. Because `agentTools()` captures `self`, the tools retain a reference to the capability instance:

```swift
@Capability
struct DatabaseTools {
    let db: DatabaseConnection

    @LLMTool("query", description: "Runs a read-only SQL query and returns results as text")
    func query(sql: String) async throws -> String {
        let rows = try await db.execute(sql)
        return rows.map(\.description).joined(separator: "\n")
    }

    @LLMTool("schema", description: "Returns the database schema for a table")
    func schema(table: String) async throws -> String {
        try await db.tableSchema(table)
    }
}

// In execute(goal:):
let tools = ToolRegistry()
tools.register(contentsOf: DatabaseTools(db: self.database).agentTools())
```

The `DatabaseTools` instance is kept alive for as long as `tools` is referenced.

## Topics

### Reference
- <doc:Capability>
