# Macro Specification: @SpecDrivenAgent

## Purpose
The `@SpecDrivenAgent` attached macro transforms a plain Swift `actor` into a production-grade, autonomous AI agent with minimal boilerplate.  

The macro must generate a **dynamic runtime reasoning loop** that enables true agentic behavior: the LLM (via Foundation Models or fallback DSL) decides at each step what to think, which tool/capability to call, or whether the goal is complete.

The macro does **not** generate static step-by-step code. All decision-making, path selection, and continuation logic happens at runtime through repeated LLM calls.

## Requirements
- Swift 6.2+ with strict concurrency checking enabled
- Platforms: iOS 18+, macOS 15+, visionOS 2+ (Foundation Models compatible)
- Dependencies: only Foundation + the three core packages:
  - SwiftSynapseMacros (this package)
  - SwiftResponsesDSL (or SwiftOpenResponsesDSL)
  - SwiftLLMToolMacros
- No additional runtime dependencies beyond Apple frameworks

## Generated Public Interface
The macro must produce the following public API on the annotated actor:

```swift
@SpecDrivenAgent
actor ExampleAgent {
    // Optional: user can override or add properties/methods
    // Macro generates everything else
}

enum AgentStatus {
    case idle
    case running
    case paused
    case error(Error)
    case completed(Any) // final result, type-erased or generic in future
}

var status: AgentStatus { get }

var transcript: ObservableTranscript { get } // @Observable collection of entries

var client: any LLMClient { get } // default: Foundation Models, injectable

func run(goal: String) async throws -> Void
// Starts the dynamic runtime loop, streams updates to transcript, updates status


## Generated Runtime Behavior — Dynamic Loop
The macro must generate a private implementation of `run(goal: String)` that contains a true runtime loop:

1. **Initialization phase**
   - Set `status = .running`
   - Clear or initialize transcript
   - Append initial `.user(goal)` entry
   - Collect all available tools/capabilities from `@Capability` instances in scope
   - Prepare initial context: goal + system prompt (if provided) + tool descriptions

2. **Main reasoning loop** (repeat until completion or termination condition)
   - Build current prompt:
     - Full transcript history (summarized if too long)
     - Current goal
     - List of available tools/capabilities (with descriptions and JSON schemas)
     - Instruction: "Think step-by-step. Use tools when needed. Output FINAL ANSWER when the goal is complete."
   - Call LLM via `client.generate(prompt: ..., tools: ...)` (prefer Foundation Models guided generation)
   - Parse LLM response:
     - If contains tool call(s) → execute each via tool registry → append `.tool(call, result)` to transcript → continue loop
     - If contains final answer (detected via "FINAL ANSWER" marker, structured JSON matching @StructuredOutput, or model signal) → append `.assistant(final)` → set `status = .completed` → exit loop
     - If error → append error entry → set `status = .error` → exit or retry
   - Stream partial thoughts/responses to transcript as `.assistant(partial)` entries

3. **Termination conditions**
   - LLM signals completion (final answer)
   - Max turns reached (default 20, configurable via macro arg in future)
   - Explicit user cancellation or error threshold

4. **Observability & safety**
   - All transcript/status updates must be observable (via Observation framework)
   - Checkpoint transcript/state for background continuation
   - Automatic retry on transient LLM errors (configurable)
   - Error handling: propagate meaningful errors to caller
   
   
   
## Macro Parameters (optional, future-proof)
Current minimal form: `@SpecDrivenAgent` (no arguments)

Future supported arguments (for flexibility):

```swift
@SpecDrivenAgent(
    maxTurns: 15,
    temperature: 0.4,
    systemPrompt: """
    You are a helpful assistant. Think step-by-step. Use tools when needed.
    """
)
