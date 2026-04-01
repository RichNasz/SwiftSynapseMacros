// Generated from CodeGenSpecs/Shared-Foundation-Models.md — Do not edit manually. Update spec and re-generate.

import Foundation
import SwiftOpenResponsesDSL

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Backend-Agnostic Types

/// A backend-agnostic prompt representation.
public struct AgentRequest: Sendable {
    public let model: String
    public let systemPrompt: String?
    public let userPrompt: String
    public let tools: [FunctionToolParam]
    public let timeoutSeconds: Int
    public let previousResponseId: String?
    public let temperature: Double?
    public let maxTokens: Int?

    public init(
        model: String,
        userPrompt: String,
        systemPrompt: String? = nil,
        tools: [FunctionToolParam] = [],
        timeoutSeconds: Int = 300,
        previousResponseId: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.tools = tools
        self.timeoutSeconds = timeoutSeconds
        self.previousResponseId = previousResponseId
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

/// A tool call requested by the model.
public struct AgentToolCall: Sendable {
    public let id: String
    public let name: String
    public let arguments: String
}

/// A backend-agnostic response.
public struct AgentResponse: Sendable {
    public let text: String?
    public let toolCalls: [AgentToolCall]
    public let responseId: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int

    public init(
        text: String?,
        toolCalls: [AgentToolCall],
        responseId: String?,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0
    ) {
        self.text = text
        self.toolCalls = toolCalls
        self.responseId = responseId
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }

    /// Whether the model requested tool execution.
    public var requiresToolExecution: Bool {
        !toolCalls.isEmpty
    }
}

// MARK: - Protocol

/// Unified abstraction over on-device and cloud inference.
///
/// Both `CloudLLMClient` and `HybridLLMClient` conform to this protocol.
/// Agents program against `AgentLLMClient`, not concrete client types.
public protocol AgentLLMClient: Sendable {
    func send(_ request: AgentRequest) async throws -> AgentResponse
    func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error>

    /// Streams structured events including text deltas and tool calls as they complete.
    ///
    /// Used by `StreamingToolExecutor` to dispatch tools while the LLM is still
    /// generating. Default implementation falls back to `send()` and yields
    /// events from the complete response.
    func streamEvents(_ request: AgentRequest) async throws -> AsyncThrowingStream<AgentStreamEvent, Error>
}

extension AgentLLMClient {
    /// Default implementation: falls back to `send()` and yields events from the complete response.
    public func streamEvents(_ request: AgentRequest) async throws -> AsyncThrowingStream<AgentStreamEvent, Error> {
        let response = try await send(request)
        return AsyncThrowingStream { continuation in
            if let text = response.text, !text.isEmpty {
                continuation.yield(.textDelta(text))
            }
            for call in response.toolCalls {
                continuation.yield(.toolCall(call))
            }
            continuation.yield(.responseComplete(
                responseId: response.responseId,
                inputTokens: response.inputTokens,
                outputTokens: response.outputTokens
            ))
            continuation.finish()
        }
    }
}

// MARK: - Cloud Implementation

/// Wraps `SwiftOpenResponsesDSL.LLMClient` as an `AgentLLMClient`.
public actor CloudLLMClient: AgentLLMClient {
    private let client: LLMClient

    public init(baseURL: String, apiKey: String = "") throws {
        self.client = try LLMClient(baseURL: baseURL, apiKey: apiKey)
    }

    /// Provides direct access to the underlying `LLMClient` for advanced use cases.
    public var underlyingClient: LLMClient { client }

    public func send(_ request: AgentRequest) async throws -> AgentResponse {
        let dslRequest = try buildRequest(from: request, stream: false)
        let response = try await client.send(dslRequest)
        return agentResponse(from: response)
    }

    public func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error> {
        let dslRequest = try buildRequest(from: request, stream: true)
        let rawStream = client.stream(dslRequest)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await event in rawStream {
                        if case .contentPartDelta(let delta, _, _) = event {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildRequest(from request: AgentRequest, stream: Bool) throws -> ResponseRequest {
        let timeout = TimeInterval(request.timeoutSeconds)
        var dslRequest = try ResponseRequest(model: request.model, stream: stream) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
        } input: {
            User(request.userPrompt)
        }
        if let systemPrompt = request.systemPrompt {
            dslRequest.instructions = systemPrompt
        }
        if !request.tools.isEmpty {
            dslRequest.tools = request.tools
        }
        if let prevId = request.previousResponseId {
            dslRequest.previousResponseId = prevId
        }
        return dslRequest
    }

    private func agentResponse(from response: ResponseObject) -> AgentResponse {
        let toolCalls = (response.firstFunctionCalls ?? []).map { call in
            AgentToolCall(id: call.callId, name: call.name, arguments: call.arguments)
        }
        return AgentResponse(
            text: response.firstOutputText,
            toolCalls: toolCalls,
            responseId: response.id,
            inputTokens: response.usage?.inputTokens ?? 0,
            outputTokens: response.usage?.outputTokens ?? 0
        )
    }
}

// MARK: - Hybrid Implementation

/// Tries on-device inference first; falls back to cloud on eligible errors.
///
/// On platforms without Foundation Models, delegates directly to the cloud client.
public actor HybridLLMClient: AgentLLMClient {
    private let cloudClient: CloudLLMClient

    public init(cloudClient: CloudLLMClient) {
        self.cloudClient = cloudClient
    }

    public func send(_ request: AgentRequest) async throws -> AgentResponse {
        // On-device path: when Foundation Models is available, try it first
        #if canImport(FoundationModels)
        do {
            return try await sendOnDevice(request)
        } catch {
            if isFallbackEligible(error) {
                return try await cloudClient.send(request)
            }
            throw error
        }
        #else
        return try await cloudClient.send(request)
        #endif
    }

    public func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        // Try on-device streaming first, fall back to cloud
        if SystemLanguageModel.default.isAvailable {
            return streamOnDevice(request)
        }
        #endif
        return try await cloudClient.stream(request)
    }

    #if canImport(FoundationModels)
    private func sendOnDevice(_ request: AgentRequest) async throws -> AgentResponse {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw AgentConfigurationError.foundationModelsUnavailable
        }

        let session: LanguageModelSession
        if let instructions = request.systemPrompt {
            session = LanguageModelSession(instructions: instructions)
        } else {
            session = LanguageModelSession()
        }

        var options = GenerationOptions()
        if let temperature = request.temperature {
            options.temperature = temperature
        }
        if let maxTokens = request.maxTokens {
            options.maximumResponseTokens = maxTokens
        }

        let response = try await session.respond(to: request.userPrompt, options: options)
        return AgentResponse(
            text: response.content,
            toolCalls: [],
            responseId: nil,
            inputTokens: 0,
            outputTokens: 0
        )
    }

    private func streamOnDevice(_ request: AgentRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let model = SystemLanguageModel.default
                    guard model.isAvailable else {
                        continuation.finish(throwing: AgentConfigurationError.foundationModelsUnavailable)
                        return
                    }

                    let session: LanguageModelSession
                    if let instructions = request.systemPrompt {
                        session = LanguageModelSession(instructions: instructions)
                    } else {
                        session = LanguageModelSession()
                    }

                    var options = GenerationOptions()
                    if let temperature = request.temperature {
                        options.temperature = temperature
                    }
                    if let maxTokens = request.maxTokens {
                        options.maximumResponseTokens = maxTokens
                    }

                    let stream = session.streamResponse(to: request.userPrompt, options: options)
                    var lastText = ""
                    for try await snapshot in stream {
                        let current = snapshot.content
                        if current.count > lastText.count {
                            let delta = String(current.dropFirst(lastText.count))
                            continuation.yield(delta)
                            lastText = current
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func isFallbackEligible(_ error: Error) -> Bool {
        if error is AgentConfigurationError {
            return true
        }
        let description = String(describing: error)
        return description.contains("modelNotReady")
            || description.contains("deviceNotEligible")
            || description.contains("appleIntelligenceNotEnabled")
            || description.contains("assetsUnavailable")
            || description.contains("foundationModelsUnavailable")
    }
    #endif
}

// MARK: - AgentConfiguration Extension

extension AgentConfiguration {
    /// Builds the appropriate `AgentLLMClient` based on execution mode.
    public func buildClient() throws -> any AgentLLMClient {
        switch executionMode {
        case .cloud:
            return try CloudLLMClient(baseURL: serverURL!, apiKey: apiKey ?? "")
        case .hybrid:
            let cloud = try CloudLLMClient(baseURL: serverURL!, apiKey: apiKey ?? "")
            return HybridLLMClient(cloudClient: cloud)
        case .onDevice:
            #if canImport(FoundationModels)
            // On-device only: use hybrid with a dummy cloud client that will never be called
            // (the on-device path handles everything; cloud is fallback that won't trigger)
            let cloud = try CloudLLMClient(baseURL: serverURL ?? "http://localhost", apiKey: "")
            return HybridLLMClient(cloudClient: cloud)
            #else
            throw AgentConfigurationError.foundationModelsUnavailable
            #endif
        }
    }

    /// Builds a raw `LLMClient` for agents that need direct DSL access.
    public func buildLLMClient() throws -> LLMClient {
        guard let url = serverURL else {
            throw AgentConfigurationError.invalidServerURL
        }
        return try LLMClient(baseURL: url, apiKey: apiKey ?? "")
    }
}
