// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Plugin Context

/// Provides access to framework registries for plugin activation.
///
/// Plugins use this context to register their tools, hooks, guardrails,
/// and configuration sources.
public struct PluginContext: Sendable {
    /// The tool registry to register tools into.
    public let toolRegistry: ToolRegistry
    /// The hook pipeline to add hooks to.
    public let hookPipeline: AgentHookPipeline
    /// The guardrail pipeline to add policies to.
    public let guardrailPipeline: GuardrailPipeline?
    /// The configuration resolver to add sources to.
    public let configResolver: ConfigurationResolver?

    public init(
        toolRegistry: ToolRegistry,
        hookPipeline: AgentHookPipeline,
        guardrailPipeline: GuardrailPipeline? = nil,
        configResolver: ConfigurationResolver? = nil
    ) {
        self.toolRegistry = toolRegistry
        self.hookPipeline = hookPipeline
        self.guardrailPipeline = guardrailPipeline
        self.configResolver = configResolver
    }
}

// MARK: - Agent Plugin Protocol

/// A modular extension that adds capabilities to an agent.
///
/// Plugins are activated before agent execution and can register tools,
/// hooks, guardrails, and configuration sources. They are deactivated
/// when the agent shuts down.
///
/// ```swift
/// struct AuditPlugin: AgentPlugin {
///     let name = "audit"
///     let version = "1.0.0"
///
///     func activate(context: PluginContext) async throws {
///         await context.hookPipeline.add(AuditLoggingHook())
///     }
///
///     func deactivate() async {}
/// }
/// ```
public protocol AgentPlugin: Sendable {
    /// Unique name for this plugin.
    var name: String { get }
    /// Version string for this plugin.
    var version: String { get }

    /// Activates the plugin, registering tools/hooks/guardrails as needed.
    func activate(context: PluginContext) async throws

    /// Deactivates the plugin and cleans up resources.
    func deactivate() async
}

// MARK: - Plugin Manager

/// Manages plugin lifecycle: registration, activation, and deactivation.
///
/// Plugins are activated in registration order and deactivated in reverse order.
public actor PluginManager {
    private var plugins: [any AgentPlugin] = []
    private var activePlugins: Set<String> = []

    public init() {}

    /// Registers a plugin. Does not activate it.
    public func register(_ plugin: any AgentPlugin) {
        plugins.append(plugin)
    }

    /// Activates all registered plugins that haven't been activated yet.
    public func activateAll(context: PluginContext, telemetry: (any TelemetrySink)? = nil) async {
        for plugin in plugins where !activePlugins.contains(plugin.name) {
            do {
                try await plugin.activate(context: context)
                activePlugins.insert(plugin.name)
                telemetry?.emit(TelemetryEvent(kind: .pluginActivated(name: plugin.name)))
            } catch {
                telemetry?.emit(TelemetryEvent(kind: .pluginError(name: plugin.name, error: error)))
            }
        }
    }

    /// Deactivates a specific plugin by name.
    public func deactivate(name: String) async {
        guard activePlugins.contains(name),
              let plugin = plugins.first(where: { $0.name == name }) else { return }
        await plugin.deactivate()
        activePlugins.remove(name)
    }

    /// Deactivates all active plugins in reverse activation order.
    public func deactivateAll() async {
        for plugin in plugins.reversed() where activePlugins.contains(plugin.name) {
            await plugin.deactivate()
            activePlugins.remove(plugin.name)
        }
    }

    /// Whether a plugin is currently active.
    public func isActive(name: String) -> Bool {
        activePlugins.contains(name)
    }

    /// Names of all registered plugins.
    public var registeredPlugins: [String] {
        plugins.map(\.name)
    }

    /// Names of all active plugins.
    public var activePluginNames: [String] {
        Array(activePlugins)
    }
}
