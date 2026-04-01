// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Configuration Priority

/// Priority levels for configuration sources. Higher values override lower ones.
public enum ConfigurationPriority: Int, Comparable, Sendable {
    /// Environment variables (lowest priority).
    case environment = 1
    /// Remote configuration service.
    case remoteConfig = 2
    /// MDM (Mobile Device Management) policy — enterprise.
    case mdmPolicy = 3
    /// User-level settings file (~/.swiftsynapse/config.json).
    case userFile = 4
    /// Project-level settings file (./swiftsynapse.json).
    case projectFile = 5
    /// Local override file (./.swiftsynapse.local.json).
    case localFile = 6
    /// CLI arguments or programmatic overrides (highest priority).
    case cliArguments = 7

    public static func < (lhs: ConfigurationPriority, rhs: ConfigurationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Configuration Source

/// A source of configuration key-value pairs.
///
/// Implement this protocol to load configuration from files, environment,
/// MDM profiles, remote services, etc.
public protocol ConfigurationSource: Sendable {
    /// The priority of this source.
    var priority: ConfigurationPriority { get }

    /// Loads key-value configuration from this source.
    func load() async throws -> [String: String]
}

// MARK: - Built-in Sources

/// Reads configuration from environment variables with a key prefix.
public struct EnvironmentConfigSource: ConfigurationSource {
    public let priority: ConfigurationPriority = .environment
    private let prefix: String

    /// Creates an environment config source.
    /// - Parameter prefix: Only environment variables starting with this prefix are included.
    ///   The prefix is stripped from key names. Default: "SWIFTSYNAPSE_".
    public init(prefix: String = "SWIFTSYNAPSE_") {
        self.prefix = prefix
    }

    public func load() async throws -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in ProcessInfo.processInfo.environment {
            if key.hasPrefix(prefix) {
                let stripped = String(key.dropFirst(prefix.count)).lowercased()
                result[stripped] = value
            }
        }
        return result
    }
}

/// Reads configuration from a JSON file.
public struct FileConfigSource: ConfigurationSource {
    public let priority: ConfigurationPriority
    private let path: URL

    public init(path: URL, priority: ConfigurationPriority) {
        self.path = path
        self.priority = priority
    }

    /// User-level config at ~/.swiftsynapse/config.json.
    public static var userDefault: FileConfigSource {
        FileConfigSource(
            path: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".swiftsynapse/config.json"),
            priority: .userFile
        )
    }

    /// Project-level config at ./swiftsynapse.json.
    public static var projectDefault: FileConfigSource {
        FileConfigSource(
            path: URL(fileURLWithPath: "swiftsynapse.json"),
            priority: .projectFile
        )
    }

    public func load() async throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: path.path) else { return [:] }
        let data = try Data(contentsOf: path)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in dict {
            result[key.lowercased()] = "\(value)"
        }
        return result
    }
}

/// Reads configuration from macOS MDM (Managed Device Management) profiles.
///
/// On macOS, enterprise policies can be pushed via MDM profiles that populate
/// UserDefaults in a managed domain.
public struct MDMConfigSource: ConfigurationSource {
    public let priority: ConfigurationPriority = .mdmPolicy
    private let domain: String

    public init(domain: String = "com.swiftsynapse.agent") {
        self.domain = domain
    }

    public func load() async throws -> [String: String] {
        #if os(macOS)
        guard let defaults = UserDefaults(suiteName: domain) else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in defaults.dictionaryRepresentation() {
            result[key.lowercased()] = "\(value)"
        }
        return result
        #else
        return [:]
        #endif
    }
}

// MARK: - Configuration Resolver

/// Merges configuration from multiple sources by priority.
///
/// Sources are loaded in priority order (lowest first). Higher-priority sources
/// override lower-priority values for the same key.
public actor ConfigurationResolver {
    private var sources: [any ConfigurationSource] = []
    private var cachedValues: [String: String]?

    public init() {}

    /// Adds a configuration source.
    public func addSource(_ source: any ConfigurationSource) {
        sources.append(source)
        cachedValues = nil
    }

    /// Resolves all sources and returns merged key-value pairs.
    public func resolve() async throws -> [String: String] {
        if let cached = cachedValues { return cached }

        let sortedSources = sources.sorted { $0.priority < $1.priority }
        var merged: [String: String] = [:]
        for source in sortedSources {
            let values = try await source.load()
            for (key, value) in values {
                merged[key] = value // Higher priority overwrites
            }
        }
        cachedValues = merged
        return merged
    }

    /// Resolves sources and builds an `AgentConfiguration`.
    public func resolveConfiguration(overrides: AgentConfiguration.Overrides = .init()) async throws -> AgentConfiguration {
        let values = try await resolve()

        let mode: ExecutionMode = overrides.executionMode
            ?? values["execution_mode"].flatMap(ExecutionMode.init(rawValue:))
            ?? .cloud

        let url: String? = overrides.serverURL
            ?? values["server_url"]

        let model: String = overrides.modelName
            ?? values["model"]
            ?? ""

        let key: String? = overrides.apiKey
            ?? values["api_key"]

        let timeout: Int = overrides.timeoutSeconds
            ?? values["timeout"].flatMap(Int.init)
            ?? 300

        let retries: Int = overrides.maxRetries
            ?? values["max_retries"].flatMap(Int.init)
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

    /// Invalidates the cached resolved values, forcing a reload on next access.
    public func invalidate() {
        cachedValues = nil
    }
}
