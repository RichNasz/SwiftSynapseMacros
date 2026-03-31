// Generated from CodeGenSpecs/Shared-Retry-Strategy.md + Shared-Tool-Concurrency.md
// Do not edit manually — update the corresponding spec file and re-generate

import Foundation
import SwiftOpenResponsesDSL

/// Core agent execution runtime.
///
/// Provides the tool dispatch loop, retry, streaming, and status management
/// that `@SpecDrivenAgent`-generated `run(goal:)` delegates to.
public enum AgentRuntime {

    /// Executes an agent goal with full tool-calling loop support.
    ///
    /// - Parameters:
    ///   - goal: The user's goal string.
    ///   - transcript: Observable transcript to record activity.
    ///   - client: The LLM client to use.
    ///   - model: Model name for the request.
    ///   - tools: Tool definitions to register with the LLM.
    ///   - toolHandlers: Map of tool name → handler closure.
    ///   - maxRetries: Maximum retry attempts for transient failures.
    ///   - maxToolIterations: Maximum tool dispatch loop iterations.
    ///   - timeoutSeconds: Request timeout in seconds.
    /// - Returns: The final text response from the LLM.
    public static func execute(
        goal: String,
        transcript: ObservableTranscript,
        client: LLMClient,
        model: String,
        tools: [FunctionToolParam] = [],
        toolHandlers: [String: @Sendable (String) async throws -> String] = [:],
        maxRetries: Int = 3,
        maxToolIterations: Int = 10,
        timeoutSeconds: Int = 300
    ) async throws -> String {
        transcript.reset()
        transcript.append(.userMessage(goal))

        let timeout = TimeInterval(timeoutSeconds)
        var request = try ResponseRequest(model: model) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
        } input: {
            User(goal)
        }
        if !tools.isEmpty {
            request.tools = tools
        }

        var iteration = 0
        while iteration <= maxToolIterations {
            try Task.checkCancellation()

            let response: ResponseObject
            let currentRequest = request
            let capturedClient = client
            response = try await retryWithBackoff(
                maxAttempts: maxRetries,
                onRetry: { _, failedAttempt in
                    let next = failedAttempt + 1
                    transcript.append(.reasoning(
                        ReasoningItem(
                            id: "retry-\(next)",
                            summary: [ReasoningSummary(type: "summary_text", text: "Retrying LLM call (attempt \(next) of \(maxRetries))\u{2026}")]
                        )
                    ))
                }
            ) {
                try await capturedClient.send(currentRequest)
            }

            // Check if the LLM wants to call tools
            guard response.requiresToolExecution,
                  let functionCalls = response.firstFunctionCalls else {
                // No tools — extract final text response
                let text = response.firstOutputText ?? ""
                guard !text.isEmpty else {
                    throw SwiftSynapseError.agentNotConfigured
                }
                transcript.append(.assistantMessage(text))
                return text
            }

            iteration += 1
            guard iteration <= maxToolIterations else {
                throw LLMError.maxIterationsExceeded(maxToolIterations)
            }

            // Execute tool calls
            var toolOutputs: [InputItem] = []
            for call in functionCalls {
                transcript.append(.toolCall(name: call.name, arguments: call.arguments))

                let start = ContinuousClock.now
                guard let handler = toolHandlers[call.name] else {
                    let duration = ContinuousClock.now - start
                    transcript.append(.toolResult(name: call.name, result: "Error: unknown tool", duration: duration))
                    throw LLMError.unknownTool(call.name)
                }
                let result = try await handler(call.arguments)
                let duration = ContinuousClock.now - start
                transcript.append(.toolResult(name: call.name, result: result, duration: duration))
                toolOutputs.append(FunctionOutput(callId: call.callId, output: result))
            }

            // Feed tool results back to LLM
            let previousId = response.id
            request = try ResponseRequest(
                model: model,
                config: {
                    try RequestTimeout(timeout)
                    try ResourceTimeout(timeout)
                    try PreviousResponseId(previousId)
                },
                input: toolOutputs
            )
            if !tools.isEmpty {
                request.tools = tools
            }
        }

        throw LLMError.maxIterationsExceeded(maxToolIterations)
    }

    // MARK: - Legacy Compatibility

    /// Simple single-turn execution (backwards compatible with the old stub).
    public static func execute(
        goal: String,
        transcript: ObservableTranscript,
        client: LLMClient,
        maxTurns: Int = 20
    ) async throws -> Any {
        let text = try await execute(
            goal: goal,
            transcript: transcript,
            client: client,
            model: "gpt-4o",
            maxToolIterations: maxTurns
        )
        return text as Any
    }
}
