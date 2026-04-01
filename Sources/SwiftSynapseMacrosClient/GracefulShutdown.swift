// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation
#if canImport(Dispatch)
import Dispatch
#endif

// MARK: - Shutdown Handler Protocol

/// A handler that performs cleanup during graceful shutdown.
///
/// Register handlers with `ShutdownRegistry` to ensure resources are
/// properly cleaned up when the application terminates.
public protocol ShutdownHandler: Sendable {
    /// Performs cleanup. Called during graceful shutdown.
    func cleanup() async
}

// MARK: - Shutdown Registry

/// Coordinates graceful shutdown by running registered cleanup handlers.
///
/// Handlers run in reverse registration order (LIFO), ensuring that
/// resources are cleaned up in the correct dependency order.
///
/// ```swift
/// let registry = ShutdownRegistry()
///
/// // Register cleanup handlers
/// await registry.register(name: "mcp") {
///     await mcpManager.disconnectAll()
/// }
/// await registry.register(name: "plugins") {
///     await pluginManager.deactivateAll()
/// }
///
/// // Install signal handlers
/// SignalHandler.install(registry: registry)
///
/// // Later, during shutdown (or triggered by signal):
/// await registry.shutdownAll()
/// ```
public actor ShutdownRegistry {
    private var handlers: [(name: String, handler: any ShutdownHandler)] = []
    public private(set) var isShuttingDown: Bool = false

    public init() {}

    /// Registers a shutdown handler.
    public func register(_ handler: any ShutdownHandler, name: String = "") {
        guard !isShuttingDown else { return }
        handlers.append((name: name, handler: handler))
    }

    /// Registers a closure-based shutdown handler.
    public func register(name: String = "", cleanup: @escaping @Sendable () async -> Void) {
        guard !isShuttingDown else { return }
        handlers.append((name: name, handler: ClosureShutdownHandler(cleanup: cleanup)))
    }

    /// Runs all registered handlers in reverse order (LIFO).
    ///
    /// Safe to call multiple times — subsequent calls are no-ops.
    public func shutdownAll() async {
        guard !isShuttingDown else { return }
        isShuttingDown = true

        // Run in reverse registration order
        for (_, handler) in handlers.reversed() {
            await handler.cleanup()
        }
        handlers.removeAll()
    }

    /// Number of registered handlers.
    public var handlerCount: Int {
        handlers.count
    }
}

// MARK: - Closure Handler

private struct ClosureShutdownHandler: ShutdownHandler {
    let cleanup: @Sendable () async -> Void

    func cleanup() async {
        await self.cleanup()
    }
}

// MARK: - Signal Handler

/// Installs POSIX signal handlers that trigger graceful shutdown.
///
/// Uses `DispatchSource` for safe signal handling. By default, installs
/// handlers for SIGINT and SIGTERM.
public final class SignalHandler: Sendable {
    /// Shared storage for active signal sources, protected by actor isolation.
    private static let storage = SignalSourceStorage()

    /// Installs signal handlers for the given signals.
    ///
    /// - Parameters:
    ///   - signals: The POSIX signals to handle. Default: [SIGINT, SIGTERM].
    ///   - registry: The shutdown registry to trigger on signal receipt.
    public static func install(
        signals: [Int32] = [SIGINT, SIGTERM],
        registry: ShutdownRegistry
    ) {
        for sig in signals {
            // Ignore the default handler
            signal(sig, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                Task {
                    await registry.shutdownAll()
                }
            }
            source.resume()
            // Keep the source alive
            Task { await storage.add(source) }
        }
    }
}

/// Actor-isolated storage for dispatch sources to prevent deallocation.
private actor SignalSourceStorage {
    private var sources: [any DispatchSourceSignal] = []

    func add(_ source: any DispatchSourceSignal) {
        sources.append(source)
    }
}
