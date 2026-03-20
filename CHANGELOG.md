# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `@SpecDrivenAgent` macro: attach to an `actor` to generate `Status` enum, status/transcript properties, `LLMClient` wrapper, and `run(_:)` method
- `@StructuredOutput` macro: attach to a `struct` to generate a `textFormat` property bridging `@LLMToolArguments` JSON schema to `TextFormat`
- `@Capability` macro: attach to a `struct` or `class` to generate an `agentTools()` method bridging `@LLMTool` types to `[AgentTool]`
- `TranscriptEntry` type: role + content wrapper for conversation history
- `AgentTool` type: bridges `ToolDefinition` and `LLMTool` types from SwiftLLMToolMacros
- `TextFormat` enum: `.jsonSchema(name:schema:strict:)` and `.text` output format variants
- `SwiftSynapseError` enum: `.agentNotConfigured` and `.clientNotInjected` error cases
- `ObservableTranscript` class: `@Observable` wrapper for SwiftUI transcript binding
- Compile-time diagnostics for macro misuse (wrong declaration kind)
- Spec-driven development structure with `CodeGenSpecs/` as source of truth
- Re-export of SwiftResponsesDSL and SwiftLLMToolMacros via `@_exported import`
