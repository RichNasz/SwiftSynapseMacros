// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Tool Protocol

/// A typed, self-describing tool that an agent can invoke.
///
/// Conform to this protocol to define tools with typed input/output and
/// automatic JSON serialization. The framework handles schema generation,
/// argument decoding, and result encoding.
///
/// ```swift
/// struct CalculateTool: AgentToolProtocol {
///     struct Input: Codable, Sendable {
///         let expression: String
///     }
///     typealias Output = String
///
///     static let name = "calculate"
///     static let description = "Evaluates a math expression"
///     static var inputSchema: FunctionToolParam { ... }
///
///     func execute(input: Input) async throws -> String {
///         // evaluate expression
///     }
/// }
/// ```
public protocol AgentToolProtocol: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable

    /// Unique tool name visible to the LLM.
    static var name: String { get }

    /// Human-readable description for the LLM.
    static var description: String { get }

    /// JSON Schema describing the input parameters.
    static var inputSchema: FunctionToolParam { get }

    /// Whether this tool can safely run concurrently with other tools.
    /// Defaults to `false` (sequential execution).
    static var isConcurrencySafe: Bool { get }

    /// Executes the tool with decoded input.
    func execute(input: Input) async throws -> Output
}

extension AgentToolProtocol {
    public static var isConcurrencySafe: Bool { false }
}

// MARK: - Tool Result

/// The result of a tool execution.
public struct ToolResult: Sendable {
    /// The tool call ID from the LLM response.
    public let callId: String
    /// The tool name.
    public let name: String
    /// The serialized output string.
    public let output: String
    /// How long the tool took to execute.
    public let duration: Duration
    /// Whether the tool completed without error.
    public let success: Bool

    public init(callId: String, name: String, output: String, duration: Duration, success: Bool) {
        self.callId = callId
        self.name = name
        self.output = output
        self.duration = duration
        self.success = success
    }
}

// MARK: - Tool Dispatch Error

/// Errors that occur during tool dispatch.
public enum ToolDispatchError: Error, Sendable {
    /// No tool registered with the given name.
    case unknownTool(String)
    /// The tool loop exceeded the maximum number of iterations.
    case loopExceeded(Int)
    /// Failed to decode tool arguments from JSON.
    case decodingFailed(tool: String, Error)
    /// Failed to encode tool output to JSON.
    case encodingFailed(tool: String, Error)
    /// A hook blocked tool execution.
    case blockedByHook(tool: String, reason: String)
    /// A permission policy denied tool execution.
    case permissionDenied(tool: String, reason: String)
}

// MARK: - Type-Erased Tool (Internal)

/// Internal type-erased wrapper enabling heterogeneous tool storage.
struct AnyAgentTool: Sendable {
    let name: String
    let definition: FunctionToolParam
    let isConcurrencySafe: Bool
    let supportsProgress: Bool
    private let _execute: @Sendable (String) async throws -> String
    private let _executeWithProgress: @Sendable (String, String, any ToolProgressDelegate) async throws -> String

    init<T: AgentToolProtocol>(_ tool: T) {
        self.name = T.name
        self.definition = T.inputSchema
        self.isConcurrencySafe = T.isConcurrencySafe
        self.supportsProgress = tool is any ProgressReportingTool

        self._execute = { arguments in
            let data = Data(arguments.utf8)
            let input: T.Input
            do {
                input = try JSONDecoder().decode(T.Input.self, from: data)
            } catch {
                throw ToolDispatchError.decodingFailed(tool: T.name, error)
            }
            let output = try await tool.execute(input: input)
            // String outputs are returned directly without JSON encoding
            // to avoid wrapping in extra quotes (e.g., "15.0" → "\"15.0\"")
            if let stringOutput = output as? String {
                return stringOutput
            }
            do {
                let encoded = try JSONEncoder().encode(output)
                guard let result = String(data: encoded, encoding: .utf8) else {
                    throw ToolDispatchError.encodingFailed(
                        tool: T.name,
                        NSError(domain: "AgentTool", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "UTF-8 encoding failed"])
                    )
                }
                return result
            } catch let error as ToolDispatchError {
                throw error
            } catch {
                throw ToolDispatchError.encodingFailed(tool: T.name, error)
            }
        }

        // Progress-aware execute: uses ProgressReportingTool if available
        if let progressTool = tool as? any ProgressReportingTool {
            self._executeWithProgress = { arguments, callId, delegate in
                try await Self._executeProgressTool(progressTool, arguments: arguments, callId: callId, delegate: delegate)
            }
        } else {
            self._executeWithProgress = { arguments, _, _ in
                let data = Data(arguments.utf8)
                let input: T.Input
                do {
                    input = try JSONDecoder().decode(T.Input.self, from: data)
                } catch {
                    throw ToolDispatchError.decodingFailed(tool: T.name, error)
                }
                let output = try await tool.execute(input: input)
                if let stringOutput = output as? String {
                    return stringOutput
                }
                do {
                    let encoded = try JSONEncoder().encode(output)
                    guard let result = String(data: encoded, encoding: .utf8) else {
                        throw ToolDispatchError.encodingFailed(
                            tool: T.name,
                            NSError(domain: "AgentTool", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "UTF-8 encoding failed"])
                        )
                    }
                    return result
                } catch let error as ToolDispatchError {
                    throw error
                } catch {
                    throw ToolDispatchError.encodingFailed(tool: T.name, error)
                }
            }
        }
    }

    private static func _executeProgressTool<T: ProgressReportingTool>(
        _ tool: T, arguments: String, callId: String, delegate: any ToolProgressDelegate
    ) async throws -> String {
        let data = Data(arguments.utf8)
        let input: T.Input
        do {
            input = try JSONDecoder().decode(T.Input.self, from: data)
        } catch {
            throw ToolDispatchError.decodingFailed(tool: T.name, error)
        }
        let output = try await tool.execute(input: input, callId: callId, progress: delegate)
        if let stringOutput = output as? String {
            return stringOutput
        }
        do {
            let encoded = try JSONEncoder().encode(output)
            guard let result = String(data: encoded, encoding: .utf8) else {
                throw ToolDispatchError.encodingFailed(
                    tool: T.name,
                    NSError(domain: "AgentTool", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "UTF-8 encoding failed"])
                )
            }
            return result
        } catch let error as ToolDispatchError {
            throw error
        } catch {
            throw ToolDispatchError.encodingFailed(tool: T.name, error)
        }
    }

    func execute(arguments: String) async throws -> String {
        try await _execute(arguments)
    }

    func execute(arguments: String, callId: String, progress: any ToolProgressDelegate) async throws -> String {
        try await _executeWithProgress(arguments, callId, progress)
    }
}
