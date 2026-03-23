# Macro Specification: @AgentGoal

## Purpose
The `@AgentGoal` macro is a freestanding macro that wraps a string literal (the agent's initial goal or system prompt) to provide compile-time validation, metadata attachment, and optional scaffolding helpers.

It encourages high-quality agentic prompts and makes goals first-class, discoverable, refactor-safe elements in the codebase.

The macro does not generate runtime logic or LLM calls — it only validates and structures the prompt for use by `@SpecDrivenAgent` or `AgentRuntime`.

## Requirements
- Swift 6.2+ (strict concurrency)
- Platforms: iOS 18+, macOS 15+, visionOS 2+
- Dependencies: only Foundation + SwiftSyntax (for macro implementation)
- No runtime dependencies beyond Apple frameworks

## Usage Syntax (what developers write)

```swift
@AgentGoal(
    maxTurns: 15,
    temperature: 0.4,
    requiresTools: true,
    preferredFormat: .jsonSchema
)
static let researchGoal = """
You are a research assistant. Think step-by-step. Use available tools when needed. 
When you have enough information, output a structured final answer in JSON matching the schema.
"""
```

All parameters are optional. Minimum valid usage:

```swift
@AgentGoal
static let simpleGoal = "Answer the user's question helpfully."
```

## Generated Output
For a declaration like:

```swift
@AgentGoal(maxTurns: 12, temperature: 0.3)
static let goal = "..."
```

The macro generates:

1. The original string constant unchanged
2. A compile-time constant with metadata:

```swift
static let goal_metadata: AgentGoalMetadata = AgentGoalMetadata(
    maxTurns: 12,
    temperature: 0.3,
    requiresTools: false,           // default
    preferredFormat: .text,         // default
    validatedPrompt: "...original string..."
)
```

3. Optional convenience extension on the agent or runtime (if desired):

```swift
extension MyAgent {
    func run(withGoal goal: StaticString) async throws { ... }
    // or similar — can be added later
}
```

## AgentGoalMetadata Type (must be generated or defined in client library)

```swift
public struct AgentGoalMetadata: Sendable {
    public let maxTurns: Int
    public let temperature: Double
    public let requiresTools: Bool
    public let preferredFormat: TextFormat // .text or .jsonSchema
    public let validatedPrompt: String
}
```

## Compile-Time Validation Rules
The macro must emit errors/warnings when:

- Prompt is empty → error: "Agent goal cannot be empty"
- maxTurns < 1 → error: "maxTurns must be at least 1"
- temperature < 0 || temperature > 2 → error: "temperature must be between 0 and 2"
- requiresTools == true but no @Capability instances are detected in scope → warning: "Goal requires tools but none are visible"
- Prompt does not contain agentic keywords ("think step-by-step", "use tools", "FINAL ANSWER") → warning: "Goal may not encourage agentic behavior — consider adding 'think step-by-step' or 'use tools'"

## Constraints & Apple Best Practices
- Macro must be freestanding (expression macro) or attached to `static let` string
- No runtime overhead — all validation and metadata generation at compile time
- Use SwiftSyntax for string analysis (keyword search, length check)
- Emit clear, actionable diagnostics (Swift-style error messages)
- Keep macro thin — no complex runtime code generation

## Acceptance Criteria for Generated Code
- Macro compiles and expands without errors on valid goals
- Invalid goals produce compiler warnings/errors with helpful messages
- `AgentGoalMetadata` is generated and accessible at compile time
- No runtime code is emitted unless explicitly requested (future helpers)
- Works with Swift 6.2+ strict concurrency (Sendable metadata)
- Integrates cleanly with `@SpecDrivenAgent` (e.g., metadata can be used by AgentRuntime)

## Future Extensions
- Add `priority: AgentPriority` (.high, .normal, .low) for scheduling
- Support prompt templates with placeholders
- Auto-generate example usage in DocC comments

Last updated: March 23, 2026
