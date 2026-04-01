// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation
import CryptoKit

// MARK: - Fixture Mode

/// Controls how the VCR client handles requests.
public enum FixtureMode: Sendable {
    /// Records responses from the real client and saves them to the fixture store.
    case record
    /// Replays responses from the fixture store without calling the real client.
    case replay
    /// Passes through to the real client without recording or replaying.
    case passthrough
}

// MARK: - Fixture Store Protocol

/// Abstract storage for VCR fixtures.
///
/// Implement this protocol to customize where fixtures are stored
/// (filesystem, in-memory, cloud, etc.).
public protocol FixtureStore: Sendable {
    /// Saves a fixture response for the given key.
    func save(key: String, response: Data) async throws
    /// Loads a fixture response for the given key, or nil if not found.
    func load(key: String) async throws -> Data?
}

// MARK: - File Fixture Store

/// Stores VCR fixtures as JSON files on disk.
///
/// Each fixture is stored as `<directory>/<key>.json`. The directory
/// is created automatically if it doesn't exist.
public actor FileFixtureStore: FixtureStore {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public init(directoryPath: String) {
        self.directory = URL(fileURLWithPath: directoryPath)
    }

    public func save(key: String, response: Data) async throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let fileURL = directory.appendingPathComponent("\(key).json")
        try response.write(to: fileURL)
    }

    public func load(key: String) async throws -> Data? {
        let fileURL = directory.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try Data(contentsOf: fileURL)
    }
}

// MARK: - VCR Response

/// A recorded LLM response for fixture replay.
private struct VCRResponse: Codable {
    let text: String?
    let toolCalls: [VCRToolCall]
    let responseId: String?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
}

private struct VCRToolCall: Codable {
    let id: String
    let name: String
    let arguments: String
}

// MARK: - VCR Client

/// A test client that records and replays LLM responses for deterministic testing.
///
/// In `.record` mode, forwards requests to a real client and saves responses.
/// In `.replay` mode, loads responses from the fixture store without network calls.
/// Request keys are SHA-256 hashes of the request content for deterministic matching.
///
/// ```swift
/// // Record fixtures during development
/// let store = FileFixtureStore(directoryPath: "Tests/Fixtures")
/// let realClient = try config.buildClient()
/// let vcr = VCRClient(client: realClient, store: store, mode: .record)
///
/// // Replay fixtures in CI
/// let vcr = VCRClient(client: realClient, store: store, mode: .replay)
///
/// // Use like any other client
/// let response = try await AgentToolLoop.run(
///     client: vcr, config: config, goal: goal,
///     tools: tools, transcript: transcript
/// )
/// ```
public actor VCRClient: AgentLLMClient {
    private let client: any AgentLLMClient
    private let store: any FixtureStore
    private let mode: FixtureMode

    public init(client: any AgentLLMClient, store: any FixtureStore, mode: FixtureMode) {
        self.client = client
        self.store = store
        self.mode = mode
    }

    public func send(_ request: AgentRequest) async throws -> AgentResponse {
        switch mode {
        case .passthrough:
            return try await client.send(request)

        case .replay:
            let key = requestKey(request)
            guard let data = try await store.load(key: key) else {
                throw VCRError.fixtureNotFound(key: key)
            }
            let recorded = try JSONDecoder().decode(VCRResponse.self, from: data)
            return agentResponse(from: recorded)

        case .record:
            let response = try await client.send(request)
            let key = requestKey(request)
            let recorded = vcrResponse(from: response)
            let data = try JSONEncoder().encode(recorded)
            try await store.save(key: key, response: data)
            return response
        }
    }

    public func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error> {
        switch mode {
        case .passthrough:
            return try await client.stream(request)

        case .replay:
            // For replay, use send() and emit the text as a single delta
            let response = try await send(request)
            return AsyncThrowingStream { continuation in
                if let text = response.text {
                    continuation.yield(text)
                }
                continuation.finish()
            }

        case .record:
            // For record, use send() to capture the full response
            let response = try await send(request)
            return AsyncThrowingStream { continuation in
                if let text = response.text {
                    continuation.yield(text)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Key Generation

    private func requestKey(_ request: AgentRequest) -> String {
        var content = "\(request.model)|\(request.userPrompt)"
        if let system = request.systemPrompt {
            content += "|\(system)"
        }
        for tool in request.tools {
            content += "|\(tool.name)"
        }
        let hash = SHA256.hash(data: Data(content.utf8))
        return hash.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Conversion

    private func vcrResponse(from response: AgentResponse) -> VCRResponse {
        VCRResponse(
            text: response.text,
            toolCalls: response.toolCalls.map { VCRToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            responseId: response.responseId,
            inputTokens: response.inputTokens,
            outputTokens: response.outputTokens,
            cacheCreationTokens: response.cacheCreationTokens,
            cacheReadTokens: response.cacheReadTokens
        )
    }

    private func agentResponse(from recorded: VCRResponse) -> AgentResponse {
        AgentResponse(
            text: recorded.text,
            toolCalls: recorded.toolCalls.map { AgentToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) },
            responseId: recorded.responseId,
            inputTokens: recorded.inputTokens,
            outputTokens: recorded.outputTokens,
            cacheCreationTokens: recorded.cacheCreationTokens,
            cacheReadTokens: recorded.cacheReadTokens
        )
    }
}

// MARK: - VCR Errors

/// Errors from VCR fixture operations.
public enum VCRError: Error, Sendable {
    /// No fixture was found for the given request key.
    case fixtureNotFound(key: String)
}
