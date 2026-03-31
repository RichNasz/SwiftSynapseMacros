// Generated from CodeGenSpecs/Shared-Configuration.md — Do not edit manually. Update spec and re-generate.

import Foundation

/// Execution mode determining which LLM backend to use.
public enum ExecutionMode: String, Codable, Sendable {
    /// On-device only via Foundation Models framework.
    case onDevice
    /// Cloud only via Open Responses API. Requires serverURL.
    case cloud
    /// Try on-device first; fall back to cloud on eligible errors. Default.
    case hybrid
}

/// Errors from `AgentConfiguration` validation.
public enum AgentConfigurationError: Error, Sendable {
    case invalidServerURL
    case invalidTimeout
    case invalidMaxRetries
    case emptyModelName
    case foundationModelsUnavailable
}

/// Centralized configuration for SwiftSynapse agents.
///
/// Replaces duplicated `serverURL`, `modelName`, `apiKey` init parameters.
/// Validated at construction time; agents trust the values without re-checking.
public struct AgentConfiguration: Codable, Sendable {
    public let executionMode: ExecutionMode
    public let serverURL: String?
    public let modelName: String
    public let apiKey: String?
    public let timeoutSeconds: Int
    public let maxRetries: Int
    public let toolResultBudgetTokens: Int

    public init(
        executionMode: ExecutionMode = .cloud,
        serverURL: String? = nil,
        modelName: String = "",
        apiKey: String? = nil,
        timeoutSeconds: Int = 300,
        maxRetries: Int = 3,
        toolResultBudgetTokens: Int = 4096
    ) throws {
        try AgentConfiguration.validate(
            executionMode: executionMode,
            serverURL: serverURL,
            modelName: modelName,
            timeoutSeconds: timeoutSeconds,
            maxRetries: maxRetries
        )
        self.executionMode = executionMode
        self.serverURL = serverURL
        self.modelName = modelName
        self.apiKey = apiKey
        self.timeoutSeconds = timeoutSeconds
        self.maxRetries = maxRetries
        self.toolResultBudgetTokens = toolResultBudgetTokens
    }

    // MARK: - Validation

    static func validate(
        executionMode: ExecutionMode,
        serverURL: String?,
        modelName: String,
        timeoutSeconds: Int,
        maxRetries: Int
    ) throws {
        switch executionMode {
        case .cloud, .hybrid:
            guard let url = serverURL, !url.isEmpty,
                  let parsed = URL(string: url),
                  parsed.scheme == "http" || parsed.scheme == "https" else {
                throw AgentConfigurationError.invalidServerURL
            }
            guard !modelName.isEmpty else {
                throw AgentConfigurationError.emptyModelName
            }
        case .onDevice:
            break
        }
        guard timeoutSeconds > 0 else {
            throw AgentConfigurationError.invalidTimeout
        }
        guard (1...10).contains(maxRetries) else {
            throw AgentConfigurationError.invalidMaxRetries
        }
    }

    // MARK: - Environment Resolution

    /// Partial overrides for `fromEnvironment`.
    public struct Overrides: Sendable {
        public let executionMode: ExecutionMode?
        public let serverURL: String?
        public let modelName: String?
        public let apiKey: String?
        public let timeoutSeconds: Int?
        public let maxRetries: Int?

        public init(
            executionMode: ExecutionMode? = nil,
            serverURL: String? = nil,
            modelName: String? = nil,
            apiKey: String? = nil,
            timeoutSeconds: Int? = nil,
            maxRetries: Int? = nil
        ) {
            self.executionMode = executionMode
            self.serverURL = serverURL
            self.modelName = modelName
            self.apiKey = apiKey
            self.timeoutSeconds = timeoutSeconds
            self.maxRetries = maxRetries
        }
    }

    /// Resolves configuration from environment variables with optional caller overrides.
    ///
    /// Priority: compiled defaults → environment variables → caller overrides.
    public static func fromEnvironment(overrides: Overrides = Overrides()) throws -> AgentConfiguration {
        let env = ProcessInfo.processInfo.environment

        let mode: ExecutionMode = overrides.executionMode
            ?? env["SWIFTSYNAPSE_EXECUTION_MODE"].flatMap(ExecutionMode.init(rawValue:))
            ?? .cloud

        let url: String? = overrides.serverURL
            ?? env["SWIFTSYNAPSE_SERVER_URL"]

        let model: String = overrides.modelName
            ?? env["SWIFTSYNAPSE_MODEL"]
            ?? ""

        let key: String? = overrides.apiKey
            ?? env["SWIFTSYNAPSE_API_KEY"]

        let timeout: Int = overrides.timeoutSeconds
            ?? env["SWIFTSYNAPSE_TIMEOUT"].flatMap(Int.init)
            ?? 300

        let retries: Int = overrides.maxRetries
            ?? env["SWIFTSYNAPSE_MAX_RETRIES"].flatMap(Int.init)
            ?? 3

        return try AgentConfiguration(
            executionMode: mode,
            serverURL: url,
            modelName: model,
            apiKey: key,
            timeoutSeconds: timeout,
            maxRetries: retries
        )
    }
}
