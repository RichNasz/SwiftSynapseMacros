# Spec: README Generation

**Generates:** `README.md` (root)

## Rules

1. The README starts with a generation header comment:
   ```
   <!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->
   ```

2. Structure:
   - **Title:** `SwiftSynapseMacros`
   - **Tagline:** One-line description of the package
   - **Overview:** 2-3 sentences explaining what the package does
   - **Requirements:** Swift version, platforms
   - **Installation:** Swift Package Manager snippet with the package URL and dependency
   - **Macros:** Section per macro (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`) with brief description and usage example
   - **Using Macros Together:** Section showing how macros combine (e.g., `@SpecDrivenAgent` actor using `@Capability` tools with `@AgentGoal` prompts and `@StructuredOutput` responses)
   - **Client Types:** Brief list of orchestration types (including `AgentStatus`, `AgentRuntime`, `AgentGoalMetadata`)
   - **Dependencies:** Table of sibling packages
   - **License:** Reference to license file if present

3. Keep the README concise — link to specs for implementation details rather than duplicating them.

4. Usage examples should be minimal and self-contained.

5. Do not include build badges, CI status, or external service links unless they exist.
