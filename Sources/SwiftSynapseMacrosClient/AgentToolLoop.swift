// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

/// A reusable tool dispatch loop that agents delegate to instead of building their own.
///
/// `AgentToolLoop.run()` handles the full send → tool calls → dispatch → send cycle,
/// including retry logic, transcript updates, hook firing, telemetry emission,
/// and multi-strategy error recovery.
///
/// ```swift
/// public func execute(goal: String) async throws -> String {
///     let client = try config.buildClient()
///     return try await AgentToolLoop.run(
///         client: client,
///         config: config,
///         goal: goal,
///         tools: tools,
///         transcript: _transcript
///     )
/// }
/// ```
public enum AgentToolLoop {
    /// Runs the tool dispatch loop until the LLM produces a final text response
    /// or the maximum number of iterations is reached.
    ///
    /// - Parameters:
    ///   - client: The LLM client to use for inference.
    ///   - config: Agent configuration (model, retries, timeouts).
    ///   - goal: The user's goal/prompt.
    ///   - tools: The tool registry containing all available tools.
    ///   - transcript: The observable transcript to update with tool calls/results.
    ///   - systemPrompt: Optional system prompt for the LLM.
    ///   - maxIterations: Maximum tool-call rounds before aborting. Default: 10.
    ///   - hooks: Optional hook pipeline for event interception.
    ///   - telemetry: Optional telemetry sink for event emission.
    ///   - budget: Optional context budget for token tracking.
    ///   - compressor: Optional transcript compressor for context management.
    ///   - recovery: Optional recovery chain for error recovery. Defaults to `.default`.
    ///   - guardrails: Optional guardrail pipeline for input/output safety checks.
    ///   - progressDelegate: Optional delegate for receiving tool progress updates.
    ///   - compactionTrigger: When to trigger transcript compression. Defaults to 80% budget utilization.
    ///   - rateLimitState: Optional rate limit state for rate-limit-aware retry behavior.
    /// - Returns: The final text response from the LLM.
    public static func run(
        client: any AgentLLMClient,
        config: AgentConfiguration,
        goal: String,
        tools: ToolRegistry,
        transcript: ObservableTranscript,
        systemPrompt: String? = nil,
        maxIterations: Int = 10,
        hooks: AgentHookPipeline? = nil,
        telemetry: (any TelemetrySink)? = nil,
        budget: inout ContextBudget?,
        compressor: (any TranscriptCompressor)? = nil,
        recovery: RecoveryChain? = .default,
        guardrails: GuardrailPipeline? = nil,
        progressDelegate: (any ToolProgressDelegate)? = nil,
        compactionTrigger: CompactionTrigger = .default,
        rateLimitState: RateLimitState? = nil
    ) async throws -> String {
        var previousResponseId: String? = nil
        var recoveryState = RecoveryState()

        let userEntry = TranscriptEntry.userMessage(goal)
        transcript.append(userEntry)
        if let hooks {
            await hooks.fire(.transcriptUpdated(entry: userEntry))
        }

        for iteration in 0..<maxIterations {
            try Task.checkCancellation()

            // Compress transcript if compaction trigger fires
            if let comp = compressor,
               compactionTrigger.shouldCompact(budget: budget, entryCount: transcript.entries.count) {
                let entriesBefore = transcript.entries.count
                let compressed = try await comp.compress(
                    entries: transcript.entries,
                    budget: budget ?? ContextBudget(maxTokens: Int.max)
                )
                transcript.sync(from: compressed)
                telemetry?.emit(TelemetryEvent(kind: .contextCompacted(
                    entriesBefore: entriesBefore,
                    entriesAfter: compressed.count,
                    strategy: String(describing: type(of: comp))
                )))
            }

            var userPrompt = iteration == 0 ? goal : ""

            var request = AgentRequest(
                model: config.modelName,
                userPrompt: userPrompt,
                systemPrompt: systemPrompt,
                tools: tools.definitions(),
                timeoutSeconds: config.timeoutSeconds,
                previousResponseId: previousResponseId,
                maxTokens: recoveryState.maxOutputTokensOverride
            )

            // Fire pre-LLM hook — can block or modify the prompt
            if let hooks {
                let action = await hooks.fire(.llmRequestSent(request: request))
                switch action {
                case .block(let reason):
                    throw ToolDispatchError.blockedByHook(tool: "llm", reason: reason)
                case .modify(let modifiedPrompt):
                    userPrompt = modifiedPrompt
                    request = AgentRequest(
                        model: config.modelName,
                        userPrompt: modifiedPrompt,
                        systemPrompt: systemPrompt,
                        tools: tools.definitions(),
                        timeoutSeconds: config.timeoutSeconds,
                        previousResponseId: previousResponseId,
                        maxTokens: recoveryState.maxOutputTokensOverride
                    )
                case .proceed:
                    break
                }
            }

            // Send with retry (rate-limit-aware when state is provided)
            let llmStart = ContinuousClock.now
            let response: AgentResponse
            let requestToSend = request // capture immutable copy for Sendable closure
            do {
                if let rateLimitState {
                    response = try await retryWithRateLimit(
                        rateLimitState: rateLimitState,
                        telemetry: telemetry
                    ) {
                        try await retryWithBackoff(
                            maxAttempts: config.maxRetries,
                            onRetry: { error, attempt in
                                telemetry?.emit(TelemetryEvent(
                                    kind: .retryAttempted(error: error, attempt: attempt)
                                ))
                            }
                        ) {
                            try await client.send(requestToSend)
                        }
                    }
                } else {
                    response = try await retryWithBackoff(
                        maxAttempts: config.maxRetries,
                        onRetry: { error, attempt in
                            telemetry?.emit(TelemetryEvent(
                                kind: .retryAttempted(error: error, attempt: attempt)
                            ))
                        }
                    ) {
                        try await client.send(requestToSend)
                    }
                }
            } catch {
                // Attempt recovery from LLM errors
                if let recoverable = classifyRecoverableError(error),
                   let recovery {
                    let result = try await recovery.attemptRecovery(
                        from: recoverable,
                        state: &recoveryState,
                        transcript: transcript,
                        compressor: compressor,
                        budget: &budget
                    )
                    if case .recovered(let continuationPrompt) = result {
                        telemetry?.emit(TelemetryEvent(kind: .retryAttempted(error: error, attempt: recoveryState.recoveryCount)))
                        // If recovery produced a continuation prompt, append it
                        if let prompt = continuationPrompt {
                            transcript.append(.userMessage(prompt))
                        }
                        continue // Retry this iteration
                    }
                }
                throw error
            }
            let llmDuration = ContinuousClock.now - llmStart

            // Track tokens
            budget?.record(inputTokens: response.inputTokens, outputTokens: response.outputTokens)

            // Emit telemetry
            telemetry?.emit(TelemetryEvent(kind: .llmCallMade(
                model: config.modelName,
                inputTokens: response.inputTokens,
                outputTokens: response.outputTokens,
                duration: llmDuration,
                cacheCreationTokens: response.cacheCreationTokens,
                cacheReadTokens: response.cacheReadTokens
            )))

            // Fire post-LLM hook
            if let hooks {
                await hooks.fire(.llmResponseReceived(response: response))
            }

            previousResponseId = response.responseId

            // If no tool calls, we're done
            if !response.requiresToolExecution {
                var result = response.text ?? ""

                // Check guardrails on LLM output
                if let guardrails {
                    let (decision, policy) = await guardrails.evaluate(input: .llmOutput(text: result))
                    switch decision {
                    case .block(let reason):
                        if let policy {
                            telemetry?.emit(TelemetryEvent(kind: .guardrailTriggered(policy: policy, risk: .high)))
                            if let hooks {
                                await hooks.fire(.guardrailTriggered(
                                    policy: policy,
                                    decision: decision,
                                    input: .llmOutput(text: result)
                                ))
                            }
                        }
                        throw GuardrailError.blocked(policy: policy ?? "unknown", reason: reason)
                    case .sanitize(let replacement):
                        result = replacement
                    case .warn, .allow:
                        break
                    }
                }

                let entry = TranscriptEntry.assistantMessage(result)
                transcript.append(entry)
                if let hooks {
                    await hooks.fire(.transcriptUpdated(entry: entry))
                }
                return result
            }

            // Fire pre-tool hook — hooks can block execution
            if let hooks {
                let action = await hooks.fire(.preToolUse(calls: response.toolCalls))
                switch action {
                case .block(let reason):
                    throw ToolDispatchError.blockedByHook(
                        tool: response.toolCalls.map(\.name).joined(separator: ", "),
                        reason: reason
                    )
                case .modify, .proceed:
                    break
                }
            }

            // Record tool calls in transcript
            for call in response.toolCalls {
                let entry = TranscriptEntry.toolCall(name: call.name, arguments: call.arguments)
                transcript.append(entry)
                if let hooks {
                    await hooks.fire(.transcriptUpdated(entry: entry))
                }
            }

            // Check guardrails on tool arguments
            if let guardrails {
                for call in response.toolCalls {
                    let (decision, policy) = await guardrails.evaluate(
                        input: .toolArguments(toolName: call.name, arguments: call.arguments)
                    )
                    switch decision {
                    case .block(let reason):
                        if let policy {
                            telemetry?.emit(TelemetryEvent(kind: .guardrailTriggered(policy: policy, risk: .high)))
                            if let hooks {
                                await hooks.fire(.guardrailTriggered(
                                    policy: policy,
                                    decision: decision,
                                    input: .toolArguments(toolName: call.name, arguments: call.arguments)
                                ))
                            }
                        }
                        throw GuardrailError.blocked(policy: policy ?? "unknown", reason: reason)
                    case .warn(_):
                        if let policy {
                            telemetry?.emit(TelemetryEvent(kind: .guardrailTriggered(policy: policy, risk: .low)))
                            if let hooks {
                                await hooks.fire(.guardrailTriggered(
                                    policy: policy,
                                    decision: decision,
                                    input: .toolArguments(toolName: call.name, arguments: call.arguments)
                                ))
                            }
                        }
                        // Warn but proceed
                        break
                    case .allow, .sanitize:
                        break
                    }
                }
            }

            // Dispatch tools
            let results = try await tools.dispatchBatch(response.toolCalls, progressDelegate: progressDelegate)

            // Emit per-tool telemetry
            for result in results {
                telemetry?.emit(TelemetryEvent(kind: .toolCalled(
                    name: result.name,
                    duration: result.duration,
                    success: result.success
                )))
            }

            // Record tool results in transcript (truncate oversized results)
            let truncationPolicy = TruncationPolicy.fromConfig(config)
            for result in results {
                let truncatedOutput = ResultTruncator.truncate(result.output, policy: truncationPolicy)
                let entry = TranscriptEntry.toolResult(
                    name: result.name,
                    result: truncatedOutput,
                    duration: result.duration
                )
                transcript.append(entry)
                if let hooks {
                    await hooks.fire(.transcriptUpdated(entry: entry))
                }
            }

            // Fire post-tool hook
            if let hooks {
                await hooks.fire(.postToolUse(results: results))
            }

            // Check budget exhaustion
            if let currentBudget = budget, currentBudget.isExhausted {
                telemetry?.emit(TelemetryEvent(kind: .tokenBudgetExhausted(
                    used: currentBudget.usedTokens,
                    limit: currentBudget.maxTokens
                )))
                throw ContextBudgetError.exhausted(
                    used: currentBudget.usedTokens,
                    limit: currentBudget.maxTokens
                )
            }
        }

        throw ToolDispatchError.loopExceeded(maxIterations)
    }

    // MARK: - Streaming Variant

    /// Runs the tool dispatch loop with stream-aware tool execution.
    ///
    /// Unlike the standard `run()`, this variant streams the LLM response and
    /// begins dispatching concurrency-safe tools as their definitions complete
    /// in the stream, reducing overall latency.
    ///
    /// Text deltas are forwarded to the transcript's streaming state for
    /// real-time UI updates.
    public static func runStreaming(
        client: any AgentLLMClient,
        config: AgentConfiguration,
        goal: String,
        tools: ToolRegistry,
        transcript: ObservableTranscript,
        systemPrompt: String? = nil,
        maxIterations: Int = 10,
        hooks: AgentHookPipeline? = nil,
        telemetry: (any TelemetrySink)? = nil,
        recovery: RecoveryChain? = .default
    ) async throws -> String {
        var previousResponseId: String? = nil
        var recoveryState = RecoveryState()

        let userEntry = TranscriptEntry.userMessage(goal)
        transcript.append(userEntry)
        if let hooks {
            await hooks.fire(.transcriptUpdated(entry: userEntry))
        }

        for iteration in 0..<maxIterations {
            try Task.checkCancellation()

            let userPrompt = iteration == 0 ? goal : ""

            let request = AgentRequest(
                model: config.modelName,
                userPrompt: userPrompt,
                systemPrompt: systemPrompt,
                tools: tools.definitions(),
                timeoutSeconds: config.timeoutSeconds,
                previousResponseId: previousResponseId,
                maxTokens: recoveryState.maxOutputTokensOverride
            )

            // Fire pre-LLM hook
            if let hooks {
                let action = await hooks.fire(.llmRequestSent(request: request))
                if case .block(let reason) = action {
                    throw ToolDispatchError.blockedByHook(tool: "llm", reason: reason)
                }
            }

            // Stream response with executor
            let executor = StreamingToolExecutor(
                tools: tools,
                hooks: hooks,
                telemetry: telemetry
            )
            var accumulatedText = ""
            var responseId: String? = nil
            var inputTokens = 0
            var outputTokens = 0

            let llmStart = ContinuousClock.now
            let eventStream: AsyncThrowingStream<AgentStreamEvent, Error>
            do {
                eventStream = try await client.streamEvents(request)
            } catch {
                // Attempt recovery
                if let recoverable = classifyRecoverableError(error),
                   let recovery {
                    var budget: ContextBudget? = nil
                    let result = try await recovery.attemptRecovery(
                        from: recoverable,
                        state: &recoveryState,
                        transcript: transcript,
                        compressor: nil,
                        budget: &budget
                    )
                    if case .recovered(let prompt) = result {
                        if let prompt { transcript.append(.userMessage(prompt)) }
                        continue
                    }
                }
                throw error
            }

            // Enable streaming mode for UI
            transcript.setStreaming(true)

            do {
                for try await event in eventStream {
                    switch event {
                    case .textDelta(let delta):
                        accumulatedText += delta
                        transcript.appendDelta(delta)

                    case .toolCall(let call):
                        // Dispatch immediately via streaming executor
                        await executor.enqueue(call)

                    case .responseComplete(let id, let inTok, let outTok):
                        responseId = id
                        inputTokens = inTok
                        outputTokens = outTok
                    }
                }
            } catch {
                transcript.setStreaming(false)
                throw error
            }

            transcript.setStreaming(false)
            let llmDuration = ContinuousClock.now - llmStart

            // Emit telemetry
            telemetry?.emit(TelemetryEvent(kind: .llmCallMade(
                model: config.modelName,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                duration: llmDuration,
                cacheCreationTokens: 0,
                cacheReadTokens: 0
            )))

            if let hooks {
                let response = AgentResponse(
                    text: accumulatedText.isEmpty ? nil : accumulatedText,
                    toolCalls: [],
                    responseId: responseId,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens
                )
                await hooks.fire(.llmResponseReceived(response: response))
            }

            previousResponseId = responseId

            // Collect tool results (waits for all safe + dispatches unsafe)
            let hasTools = await executor.hasTools
            if !hasTools {
                // No tool calls — final response
                let entry = TranscriptEntry.assistantMessage(accumulatedText)
                transcript.append(entry)
                if let hooks {
                    await hooks.fire(.transcriptUpdated(entry: entry))
                }
                return accumulatedText
            }

            // Record tool calls + results in transcript
            let results = try await executor.awaitAll()
            for result in results {
                transcript.append(.toolCall(name: result.name, arguments: ""))
                let entry = TranscriptEntry.toolResult(
                    name: result.name,
                    result: result.output,
                    duration: result.duration
                )
                transcript.append(entry)
                if let hooks {
                    await hooks.fire(.transcriptUpdated(entry: entry))
                }
            }

            if let hooks {
                await hooks.fire(.postToolUse(results: results))
            }
        }

        throw ToolDispatchError.loopExceeded(maxIterations)
    }

    /// Convenience overload without context budget management.
    public static func run(
        client: any AgentLLMClient,
        config: AgentConfiguration,
        goal: String,
        tools: ToolRegistry,
        transcript: ObservableTranscript,
        systemPrompt: String? = nil,
        maxIterations: Int = 10,
        hooks: AgentHookPipeline? = nil,
        telemetry: (any TelemetrySink)? = nil,
        guardrails: GuardrailPipeline? = nil,
        progressDelegate: (any ToolProgressDelegate)? = nil
    ) async throws -> String {
        var budget: ContextBudget? = nil
        return try await run(
            client: client,
            config: config,
            goal: goal,
            tools: tools,
            transcript: transcript,
            systemPrompt: systemPrompt,
            maxIterations: maxIterations,
            hooks: hooks,
            telemetry: telemetry,
            budget: &budget,
            compressor: nil,
            recovery: .default,
            guardrails: guardrails,
            progressDelegate: progressDelegate
        )
    }
}
