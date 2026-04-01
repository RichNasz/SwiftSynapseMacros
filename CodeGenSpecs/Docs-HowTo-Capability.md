# Spec: HowTo — Using @Capability

**Generates:** `Sources/SwiftSynapseMacrosClient/SwiftSynapseMacrosClient.docc/HowTo-Capability.md`

## Purpose

A task-oriented HowTo guide for `@Capability`. Readers arrive here wanting to define a group of tools and register them with an agent. The guide shows the full `@Capability` → `@LLMTool` → `ToolRegistry` flow.

## DocC Metadata

```
@Metadata {
    @PageKind(article)
}
```

Title: `Using @Capability`

## Article Structure

### Introduction (2 sentences)

`@Capability` groups related tools into a single type, making it easy to compose and reuse tool sets across agents. This guide shows how to define a capability, annotate tools within it, register it with an agent, and combine multiple capabilities. For the generated member reference, see `<doc:Capability>`.

---

### Task 1: Define a Capability with Multiple Tools

**Goal:** Create a namespaced group of tools that an agent can use.

Apply `@Capability` to a `struct`. Annotate each tool method with `@LLMTool`:

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
}
```

`@Capability` generates `agentTools() -> [AgentTool]` which collects all `@LLMTool` methods into an array. Methods without `@LLMTool` are not included.

---

### Task 2: Register Tools with an Agent

**Goal:** Make the capability's tools available to an agent's tool loop.

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

The agent can now call any of the three file system tools. The LLM sees their descriptions and decides when to invoke them.

---

### Task 3: Combine Multiple Capabilities

**Goal:** Give an agent access to tools from two or more capability types.

Create each capability type independently, then register both:

```swift
@Capability
struct WebTools {
    @LLMTool("fetchURL", description: "Fetches the content of a URL")
    func fetchURL(url: String) async throws -> String { ... }
}

// In execute(goal:):
let tools = ToolRegistry()
tools.register(contentsOf: FileSystemTools().agentTools())
tools.register(contentsOf: WebTools().agentTools())
// Agent now has access to all 4 tools across both capabilities
```

This is the primary benefit of `@Capability`: you compose agents from independent, reusable tool groups rather than registering tools one by one.

---

### Task 4: Use a Stateful Capability

**Goal:** Inject dependencies into a capability (database connection, API client, etc.).

Since `@Capability` can be applied to a class, capabilities can hold state:

```swift
@Capability
struct DatabaseTools {
    let db: DatabaseConnection

    @LLMTool("query", description: "Runs a read-only SQL query")
    func query(sql: String) async throws -> String {
        let rows = try await db.execute(sql)
        return rows.map(\.description).joined(separator: "\n")
    }
}

// In execute(goal:):
let tools = ToolRegistry()
tools.register(contentsOf: DatabaseTools(db: self.database).agentTools())
```

The `DatabaseTools` instance captures `db` in its closure when `agentTools()` is called — tools retain a reference to the capability instance.

## Tone and Length

Practical, with emphasis on the composition pattern (Task 3) since that's the primary value. Aim for ~400–500 words plus code blocks. Task 4 (stateful capability) can be brief — one short example is enough.
