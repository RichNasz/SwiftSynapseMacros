# Spec: Production Polish

**Generates:**
- `Sources/SwiftSynapseMacrosClient/CostTracking.swift`
- `Sources/SwiftSynapseMacrosClient/ErrorClassification.swift`
- `Sources/SwiftSynapseMacrosClient/ResultTruncation.swift`
- `Sources/SwiftSynapseMacrosClient/RateLimiting.swift`
- `Sources/SwiftSynapseMacrosClient/SystemPromptBuilder.swift`
- `Sources/SwiftSynapseMacrosClient/TestFixtures.swift`
- `Sources/SwiftSynapseMacrosClient/GracefulShutdown.swift`
- `Sources/SwiftSynapseMacrosClient/AgentMemory.swift`
- `Sources/SwiftSynapseMacrosClient/ConversationRecovery.swift`

## Overview

Production polish capabilities that close the operational gap between a working agent harness and a production-deployed one. Each capability is modular, opt-in, and integrates through established extension points (telemetry sinks, hook events, function parameters).

---

## Cost Tracking

Per-session cost accumulation across all LLM calls with per-model pricing.

- `ModelPricing` struct: Per-model token pricing (input, output, cache creation, cache read costs per million tokens). Method: `cost(inputTokens:outputTokens:cacheCreationTokens:cacheReadTokens:) -> Decimal`.
- `CostRecord` struct: Single LLM call record (model, tokens, cost, apiDuration, timestamp).
- `ModelUsage` struct: Aggregated per-model summary (total tokens, cost, call count).
- `CostTracker` actor: Accumulates records. `setPricing(for:pricing:)`, `record(model:inputTokens:outputTokens:...)`, `totalCost()`, `totalAPIDuration()`, `usageByModel()`, `allRecords()`, `reset()`.
- `CostTrackingTelemetrySink` struct: Conforms to `TelemetrySink`, listens for `.llmCallMade` events and delegates to `CostTracker`. Zero changes to AgentToolLoop.
- **Integration:** `AgentResponse` extended with `cacheCreationTokens` and `cacheReadTokens` (defaulted to 0). `TelemetryEventKind.llmCallMade` extended with cache token fields (defaulted, non-breaking).

---

## Semantic Error Classification

Structured error typing for API and tool errors.

- `APIErrorCategory` enum: `.auth`, `.quota`, `.rateLimit(retryAfterSeconds:)`, `.connectivity`, `.serverError`, `.badRequest`, `.unknown`.
- `ToolErrorCategory` enum: `.inputDecoding`, `.executionFailure`, `.timeout`, `.permissionDenied`, `.unknown`.
- `ClassifiedError` struct: Wraps original `Error` with `category`, `model`, `isRetryable`, `retryAfterSeconds`.
- `classifyAPIError(_:model:)` function: Inspects error description for HTTP status codes, error message patterns. Returns `ClassifiedError`.
- `classifyToolError(_:toolName:)` function: Classifies tool execution errors.
- **Integration:** `classifyRecoverableError()` in RecoveryStrategy.swift delegates to `classifyAPIError()` for consistent classification. New telemetry event: `.apiErrorClassified(category:model:)`.

---

## Tool Result Truncation

Graceful handling of oversized tool results to prevent context window waste.

- `TruncationPolicy` struct: `maxCharacters` (default 16384), `preserveLastCharacters` (default 200). Static `fromConfig(_:)` factory using `toolResultBudgetTokens * 4`.
- `ResultTruncator` enum: Static `truncate(_:policy:)` — returns original if under limit, otherwise `[Truncated: N chars total, showing last M]\n...\nsuffix`. Static `truncatePath(_:maxLength:)` for path display.
- **Integration:** Applied in `AgentToolLoop.run()` after tool dispatch, before appending results to transcript. Uses existing `config.toolResultBudgetTokens`.

---

## Rate Limit Handling

Rate-limit-aware retry with cooldown tracking, separate from general retry logic.

- `RateLimitPolicy` struct: `maxRetries`, `initialBackoff`, `maxBackoff`, `jitterFactor`. Static `.default`.
- `RateLimitError` enum: `.rateLimited(retryAfter:)`, `.serverOverloaded(retryAfter:)`, `.retriesExhausted(lastError:)`.
- `RateLimitState` actor: Per-model cooldown tracking. `isInCooldown`, `remainingCooldown`, `consecutiveHits`, `enterCooldown(duration:)`, `recordSuccess()`, `waitForCooldown()`.
- `retryWithRateLimit()` function: Wraps operation with rate-limit-aware behavior — checks cooldown before send, classifies errors via `classifyAPIError`, enters cooldown on rate limit, jittered exponential backoff.
- **Integration:** `AgentToolLoop.run()` accepts optional `rateLimitState` parameter. When provided, wraps the retry call with `retryWithRateLimit`.

---

## System Prompt Composition

Composable, prioritized system prompt building with cache boundary awareness.

- `SystemPromptSection` struct: `id`, `content`, `priority` (ordering), `cacheable` flag.
- `SystemPromptProvider` protocol: `systemPromptSections() -> [SystemPromptSection]`. Tools/plugins can co-locate prompt instructions with implementation.
- `SystemPromptBuilder` actor: `addSection()`, `addDynamicSection(resolver:)`, `addProvider()`, `removeSection(id:)`, `build() -> String` (concatenates by priority), `buildWithCacheBoundaries() -> [(content, cacheable)]`, `clear()`.
- **Integration:** Standalone utility — callers build the prompt and pass it as `systemPrompt: String?` to `AgentToolLoop.run()`. No signature changes required.

---

## VCR Testing Utilities

Deterministic agent testing via request/response recording and replay.

- `FixtureMode` enum: `.record`, `.replay`, `.passthrough`.
- `FixtureStore` protocol: `save(key:response:)`, `load(key:) -> Data?`.
- `FileFixtureStore` actor: JSON fixtures in configurable directory.
- `VCRClient` actor: Conforms to `AgentLLMClient`. Records/replays responses by SHA-256 hash of request content (model + prompt + tools). In `.record` mode, forwards to real client and saves. In `.replay` mode, loads from store.
- `VCRError` enum: `.fixtureNotFound(key:)`.
- **Integration:** Drops in anywhere an `AgentLLMClient` is used. No changes to existing code.

---

## Graceful Shutdown

Coordinated resource cleanup on application termination.

- `ShutdownHandler` protocol: `cleanup() async`.
- `ShutdownRegistry` actor: `register(_:name:)`, `register(name:cleanup:)` (closure), `shutdownAll()` (reverse order, idempotent), `isShuttingDown`, `handlerCount`.
- `SignalHandler` class: `install(signals:registry:)` — installs POSIX signal handlers (SIGINT, SIGTERM) via `DispatchSource` that trigger `registry.shutdownAll()`.
- **Integration:** Callers register `PluginManager.deactivateAll()` and `MCPManager.disconnectAll()` as shutdown handlers at the application level. No changes to existing files.

---

## Agent Memory (Cross-Session)

Persistent agent memory across sessions, distinct from session persistence and team memory.

- `MemoryCategory` enum (Codable): `.user`, `.feedback`, `.project`, `.reference`, `.custom(String)`.
- `MemoryEntry` struct (Codable, Identifiable): `id`, `category`, `content`, `createdAt`, `lastAccessedAt`, `accessCount`, `tags`.
- `MemoryStore` protocol: `save()`, `retrieve(category:limit:)`, `search(query:limit:)`, `delete(id:)`, `all()`, `clear()`.
- `FileMemoryStore` actor: JSON file-per-entry in `~/.swiftsynapse/memory/`. Entries named by id.
- **Integration:** New hook event: `.memoryUpdated(entry:)`. Distinct from `TeamMemory` (coordination-scoped, in-memory) and `SessionStore` (single-session snapshots).

---

## Conversation Recovery

Transcript consistency checking and repair after interruptions.

- `IntegrityViolation` enum: `.orphanedToolCall(name:index:)`, `.orphanedToolResult(name:index:)`, `.invalidSequence(expected:found:index:)`.
- `TranscriptIntegrityCheck` struct: `check(_:) -> [IntegrityViolation]`. Validates tool call/result pairing.
- `ConversationRecoveryStrategy` protocol: `repair(transcript:violations:) -> [TranscriptEntry]`.
- `DefaultConversationRecoveryStrategy` struct: Appends synthetic error results for orphaned calls, removes orphaned results.
- `recoverTranscript(_:strategy:)` function: Validates and repairs in one call.
- **Integration:** New hook event: `.transcriptRepaired(violations:)`.
