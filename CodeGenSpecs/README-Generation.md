# Spec: README Generation

**Generates:** `README.md` (root)

## Rules

1. The README starts with a generation header comment:
   ```
   <!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->
   ```

2. Structure (in order):
   - **Title:** `SwiftSynapseMacros`
   - **Tagline:** One-line description of the package
   - **Overview:** 2-3 sentences. Covers only what actually lives in this package: macros that generate agent scaffolding, and the core types that macro-generated code depends on. Does NOT mention SwiftSynapseUI (which lives in SwiftSynapseHarness).
   - **Documentation:** Two paths for reading the full documentation: (1) hosted on GitHub Pages at the project's Pages URL, (2) locally in Xcode via Product > Build Documentation. The GitHub Pages link is the easiest entry point; Xcode is the richest experience during development.
   - **Package Architecture:** (see section 3 below)
   - **Requirements:** Swift version, platforms
   - **Installation:** (see section 4 below)
   - **Macros:** Section per macro (`@SpecDrivenAgent`, `@StructuredOutput`, `@Capability`, `@AgentGoal`) with brief description and usage example
   - **Using Macros Together:** Section showing how macros combine
   - **Core Types:** Brief list of orchestration types
   - **Dependencies:** Table of sibling packages
   - **License:** Reference to license file if present

3. Keep the README concise — link to specs for implementation details rather than duplicating them.

4. Usage examples should be minimal and self-contained.

5. Do not include build badges, CI status, or external service links unless they exist.

---

## Section 2a: Documentation

This section should appear immediately after the Overview (before Package Architecture) to orient users early.

### Content to convey:

The full documentation for this package is available as DocC via two paths:

**GitHub Pages (easiest — no Xcode required):**
Browse the hosted docs at:
`https://richnasz.github.io/SwiftSynapseMacros/documentation/swiftsynapsemacrosclient/`

**Xcode Developer Documentation (richest experience during development):**

1. Open the project or any project that depends on this package in Xcode.
2. Choose **Product > Build Documentation** (or open the Documentation window via the menu).
3. Navigate to **SwiftSynapseMacros** in the documentation navigator.

Both paths render the same macro reference pages, HowTo guides, and integration guides. The `README` covers installation and orientation only; the DocC documentation covers usage in depth.

### Formatting guidance:

- Lead with the GitHub Pages link — it works without any tooling.
- Use a numbered list for the Xcode steps (they are sequential).
- Do not duplicate DocC content in the README.
- The GitHub Pages docs are deployed automatically on push to `main` via `.github/workflows/deploy-docs.yml`.

---

## Section 3: Package Architecture

This section is critical for orienting readers — especially those who are not familiar with Swift macros. It should appear after the Overview and before Requirements. Write it in plain, accessible prose. The goal is to answer "why does this repo exist and why is Package.swift structured this way?" for a developer who landed here from a Google search or a dependency graph.

### Content to convey:

**Why this is a separate package from SwiftSynapseHarness:**

Swift's compiler plugin system has a hard constraint: `.macro()` targets can only depend on swift-syntax — they cannot import user packages. This means the macro plugin and its associated type declarations must live in an isolated package. SwiftSynapseHarness depends on SwiftSynapseMacros (not the reverse). The separation is a compiler requirement, not an architectural preference.

**The 3-target structure (explain the role of each):**

- `SwiftSynapseMacros` (`.macro` target): the compiler plugin. Runs during `swift build` — never imported at runtime. Constrained to SwiftSyntax only by the Swift compiler. Most Swift developers will never write code like this; understanding it is not required to use the package.
- `SwiftSynapseMacrosClient` (`.target`): the importable library. Contains `#externalMacro` declarations that activate the plugin, the core types that macro-generated code relies on (`AgentStatus`, `ObservableTranscript`, etc.), and `@_exported import` of sibling packages. This is what `SwiftSynapseHarness` depends on.
- `SwiftSynapseMacrosTests`: validates that each macro expands to the correct source code — not runtime tests, but compile-time expansion snapshots.

**Only one product is exported (`SwiftSynapseMacrosClient`):** The `.macro` target is activated automatically when you depend on `SwiftSynapseMacrosClient` — no explicit product declaration needed.

### Formatting guidance:

- Use a short intro sentence, then a small table or three-bullet list for the targets
- Keep the "why separate" explanation to 2-3 sentences — it's context, not the main topic
- End with a one-sentence note on the dependency direction: "SwiftSynapseHarness → SwiftSynapseMacros (not the reverse)"

---

## Section 4: Installation

This section must clearly differentiate three user types so readers get to the right setup immediately. Avoid a single generic SPM snippet without context.

### Content to convey:

**Most users — building agents with `@SpecDrivenAgent`:**

Add `SwiftSynapseHarness`. It re-exports everything from this package via `@_exported import SwiftSynapseMacrosClient`, so a single `import SwiftSynapseHarness` gives access to all macros, types, and the full agent runtime. SwiftSynapseMacros is fetched automatically as a transitive dependency.

```swift
// In Package.swift
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main")
// In your target dependencies
.product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness")
```

```swift
// In source files — one import covers everything
import SwiftSynapseHarness
```

**Rare — using macros without the full harness:**

Only needed when you want the compile-time macros and core types but not the runtime (tool loop, hooks, LLM client, etc.).

```swift
.package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main")
// depend on "SwiftSynapseMacrosClient"
```

**Macro contributors — extending the compiler plugin:**

Work directly with this package. See `CodeGenSpecs/Macros-*.md` for spec-driven contribution workflow.

### Formatting guidance:

- Lead with the common case (SwiftSynapseHarness) — it should be the first and most prominent path
- Use `###` subheadings or a bold label for each path so readers can scan quickly
- Keep the rare/contributor paths visually subordinate (less code, shorter explanation)
