// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - MCP Message (JSON-RPC 2.0)

/// A JSON-RPC 2.0 message used by the Model Context Protocol.
public struct MCPMessage: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int?
    public let method: String?
    public let params: AnyCodable?
    public let result: AnyCodable?
    public let error: MCPError?

    public init(id: Int? = nil, method: String? = nil, params: AnyCodable? = nil, result: AnyCodable? = nil, error: MCPError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }

    /// Creates a request message.
    public static func request(id: Int, method: String, params: AnyCodable? = nil) -> MCPMessage {
        MCPMessage(id: id, method: method, params: params)
    }

    /// Creates a notification (no id, no response expected).
    public static func notification(method: String, params: AnyCodable? = nil) -> MCPMessage {
        MCPMessage(method: method, params: params)
    }
}

/// An MCP error response.
public struct MCPError: Codable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: AnyCodable?

    public init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

/// Type-erased JSON value for MCP message params/results.
public struct AnyCodable: Codable, Sendable {
    public let value: Any & Sendable

    public init(_ value: some Codable & Sendable) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = Optional<String>.none as Any & Sendable
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: AnyCodable] {
            try container.encode(dict)
        } else if let array = value as? [AnyCodable] {
            try container.encode(array)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - MCP Transport

/// Abstract transport for MCP communication.
///
/// Implement this protocol to support different transport mechanisms
/// (stdio, SSE, WebSocket) for connecting to MCP servers.
public protocol MCPTransport: Sendable {
    /// Sends a JSON-RPC message to the server.
    func send(_ message: MCPMessage) async throws

    /// Receives messages from the server as an async stream.
    func receive() -> AsyncThrowingStream<MCPMessage, Error>

    /// Closes the transport connection.
    func close() async
}

// MARK: - Stdio Transport

/// An MCP transport that communicates via stdin/stdout of a child process.
public actor StdioMCPTransport: MCPTransport {
    private let command: String
    private let arguments: [String]
    private let environment: [String: String]
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?

    public init(command: String, arguments: [String] = [], environment: [String: String] = [:]) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
    }

    /// Starts the child process if not already running.
    public func start() throws {
        guard process == nil else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: command)
        proc.arguments = arguments
        if !environment.isEmpty {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment { env[key] = value }
            proc.environment = env
        }

        let input = Pipe()
        let output = Pipe()
        proc.standardInput = input
        proc.standardOutput = output
        proc.standardError = FileHandle.nullDevice

        try proc.run()
        self.process = proc
        self.inputPipe = input
        self.outputPipe = output
    }

    nonisolated public func send(_ message: MCPMessage) async throws {
        let data = try JSONEncoder().encode(message)
        let header = "Content-Length: \(data.count)\r\n\r\n"
        guard let headerData = header.data(using: .utf8) else { return }
        let pipe = await self.inputPipe
        pipe?.fileHandleForWriting.write(headerData)
        pipe?.fileHandleForWriting.write(data)
    }

    nonisolated public func receive() -> AsyncThrowingStream<MCPMessage, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let pipe = await self.outputPipe else {
                    continuation.finish()
                    return
                }
                let handle = pipe.fileHandleForReading
                let decoder = JSONDecoder()

                while true {
                    // Read Content-Length header
                    guard let headerLine = await Self.readLine(from: handle),
                          headerLine.hasPrefix("Content-Length:") else {
                        continuation.finish()
                        return
                    }
                    let lengthStr = headerLine.dropFirst("Content-Length:".count).trimmingCharacters(in: .whitespaces)
                    guard let length = Int(lengthStr) else {
                        continuation.finish()
                        return
                    }

                    // Skip empty line after header
                    _ = await Self.readLine(from: handle)

                    // Read body
                    let bodyData = handle.readData(ofLength: length)
                    guard bodyData.count == length else {
                        continuation.finish()
                        return
                    }

                    do {
                        let message = try decoder.decode(MCPMessage.self, from: bodyData)
                        continuation.yield(message)
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }
            }
        }
    }

    private static func readLine(from handle: FileHandle) async -> String? {
        var buffer = Data()
        while true {
            let byte = handle.readData(ofLength: 1)
            guard !byte.isEmpty else { return nil }
            if byte[0] == UInt8(ascii: "\n") {
                return String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .carriageReturn)
            }
            buffer.append(byte)
        }
    }

    public func close() async {
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
    }
}

private extension CharacterSet {
    static let carriageReturn = CharacterSet(charactersIn: "\r")
}

// MARK: - MCP Tool Definition (from server)

/// A tool definition discovered from an MCP server.
public struct MCPToolDefinition: Codable, Sendable {
    public let name: String
    public let description: String?
    public let inputSchema: [String: AnyCodable]?

    public init(name: String, description: String? = nil, inputSchema: [String: AnyCodable]? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

// MARK: - MCP Server Configuration

/// Configuration for connecting to an MCP server.
public struct MCPServerConfig: Codable, Sendable {
    /// Display name for the server.
    public let name: String
    /// Transport type.
    public let transport: MCPTransportType
    /// Command to launch (for stdio transport).
    public let command: String?
    /// Arguments for the command.
    public let arguments: [String]
    /// URL for SSE/WebSocket transports.
    public let url: String?
    /// Environment variables to pass to the server process.
    public let environment: [String: String]

    public init(
        name: String,
        transport: MCPTransportType = .stdio,
        command: String? = nil,
        arguments: [String] = [],
        url: String? = nil,
        environment: [String: String] = [:]
    ) {
        self.name = name
        self.transport = transport
        self.command = command
        self.arguments = arguments
        self.url = url
        self.environment = environment
    }
}

/// The transport mechanism for an MCP server connection.
public enum MCPTransportType: String, Codable, Sendable {
    case stdio
    case sse
    case webSocket
}

// MARK: - MCP Server Connection

/// Manages the lifecycle of a connection to a single MCP server.
///
/// Handles initialization handshake, capability negotiation, tool discovery,
/// and clean shutdown.
public actor MCPServerConnection {
    private let config: MCPServerConfig
    private var transport: (any MCPTransport)?
    private var nextRequestId: Int = 1
    private var pendingRequests: [Int: CheckedContinuation<MCPMessage, Error>] = [:]
    private var discoveredTools: [MCPToolDefinition] = []
    private var receiveTask: Task<Void, Never>?

    public init(config: MCPServerConfig) {
        self.config = config
    }

    /// Connects to the server and performs the initialization handshake.
    public func connect() async throws {
        let t: any MCPTransport
        switch config.transport {
        case .stdio:
            guard let command = config.command else {
                throw MCPConnectionError.missingCommand
            }
            let stdio = StdioMCPTransport(
                command: command,
                arguments: config.arguments,
                environment: config.environment
            )
            try await stdio.start()
            t = stdio
        case .sse, .webSocket:
            throw MCPConnectionError.unsupportedTransport(config.transport.rawValue)
        }
        self.transport = t

        // Start receiving messages
        receiveTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await message in t.receive() {
                    await self.handleMessage(message)
                }
            } catch {
                // Connection closed or error — stop receiving
            }
        }

        // Send initialize request
        let initResult = try await sendRequest(
            method: "initialize",
            params: AnyCodable([
                "protocolVersion": AnyCodable("2024-11-05"),
                "capabilities": AnyCodable([String: AnyCodable]()),
                "clientInfo": AnyCodable([
                    "name": AnyCodable("SwiftSynapse"),
                    "version": AnyCodable("1.0.0"),
                ]),
            ])
        )
        _ = initResult

        // Send initialized notification
        try await transport?.send(.notification(method: "notifications/initialized"))
    }

    /// Discovers tools available on the server.
    public func discoverTools() async throws -> [MCPToolDefinition] {
        let response = try await sendRequest(method: "tools/list")
        if let result = response.result,
           let dict = result.value as? [String: AnyCodable],
           let toolsValue = dict["tools"],
           let toolsArray = toolsValue.value as? [AnyCodable] {
            // Decode tools from the response
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            var tools: [MCPToolDefinition] = []
            for toolValue in toolsArray {
                if let data = try? encoder.encode(toolValue),
                   let tool = try? decoder.decode(MCPToolDefinition.self, from: data) {
                    tools.append(tool)
                }
            }
            discoveredTools = tools
            return tools
        }
        return []
    }

    /// Calls a tool on the server.
    public func callTool(name: String, arguments: String) async throws -> String {
        let argsData = Data(arguments.utf8)
        let argsDecoded = (try? JSONDecoder().decode([String: AnyCodable].self, from: argsData)) ?? [:]

        let response = try await sendRequest(
            method: "tools/call",
            params: AnyCodable([
                "name": AnyCodable(name),
                "arguments": AnyCodable(argsDecoded),
            ])
        )

        if let error = response.error {
            throw error
        }

        if let result = response.result {
            let data = try JSONEncoder().encode(result)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }

    /// Disconnects from the server.
    public func disconnect() async {
        receiveTask?.cancel()
        receiveTask = nil
        await transport?.close()
        transport = nil
    }

    // MARK: - Private

    private func sendRequest(method: String, params: AnyCodable? = nil) async throws -> MCPMessage {
        guard let transport else {
            throw MCPConnectionError.notConnected
        }

        let id = nextRequestId
        nextRequestId += 1

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
            Task {
                do {
                    try await transport.send(.request(id: id, method: method, params: params))
                } catch {
                    if let cont = pendingRequests.removeValue(forKey: id) {
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func handleMessage(_ message: MCPMessage) {
        guard let id = message.id, let continuation = pendingRequests.removeValue(forKey: id) else {
            return // Notification or unknown response
        }
        continuation.resume(returning: message)
    }
}

/// Errors from MCP server connections.
public enum MCPConnectionError: Error, Sendable {
    case notConnected
    case missingCommand
    case unsupportedTransport(String)
    case handshakeFailed(String)
}

// MARK: - MCP Tool Bridge

/// Wraps an MCP-discovered tool as an `AgentToolProtocol` tool.
///
/// This bridge makes MCP tools appear as native SwiftSynapse tools,
/// allowing them to be registered in a `ToolRegistry` and dispatched
/// alongside local tools.
public struct MCPToolBridge: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let arguments: String

        public init(arguments: String) {
            self.arguments = arguments
        }
    }
    public typealias Output = String

    public static let name = ""
    public static let description = ""
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: "",
            description: "",
            parameters: .object(properties: [], required: []),
            strict: false
        )
    }

    /// The actual tool name from the MCP server.
    public let toolName: String
    /// Description from the MCP server.
    public let toolDescription: String
    private let connection: MCPServerConnection

    public init(definition: MCPToolDefinition, connection: MCPServerConnection) {
        self.toolName = definition.name
        self.toolDescription = definition.description ?? ""
        self.connection = connection
    }

    public func execute(input: Input) async throws -> String {
        try await connection.callTool(name: toolName, arguments: input.arguments)
    }

    /// Returns the tool definition for LLM registration.
    /// Uses the actual tool name and description, not the static protocol defaults.
    public var dynamicSchema: FunctionToolParam {
        FunctionToolParam(
            name: toolName,
            description: toolDescription,
            parameters: .object(properties: [], required: []),
            strict: false
        )
    }
}

// MARK: - MCP Manager

/// Manages multiple MCP server connections and registers their tools.
///
/// Use this to connect to MCP servers defined in configuration and make
/// their tools available to agents via the `ToolRegistry`.
public actor MCPManager {
    private var connections: [String: MCPServerConnection] = [:]
    private var bridges: [MCPToolBridge] = []

    public init() {}

    /// Adds and connects to an MCP server.
    public func addServer(_ config: MCPServerConfig) async throws {
        let connection = MCPServerConnection(config: config)
        try await connection.connect()
        connections[config.name] = connection
    }

    /// Discovers tools from all connected servers.
    public func discoverTools() async throws -> [MCPToolBridge] {
        var allBridges: [MCPToolBridge] = []
        for (_, connection) in connections {
            let tools = try await connection.discoverTools()
            for tool in tools {
                allBridges.append(MCPToolBridge(definition: tool, connection: connection))
            }
        }
        bridges = allBridges
        return allBridges
    }

    /// Registers all discovered MCP tools into a tool registry.
    public func registerAll(in registry: ToolRegistry) async throws {
        let tools = try await discoverTools()
        for tool in tools {
            registry.register(tool)
        }
    }

    /// Disconnects from all servers.
    public func disconnectAll() async {
        for (_, connection) in connections {
            await connection.disconnect()
        }
        connections.removeAll()
        bridges.removeAll()
    }
}
