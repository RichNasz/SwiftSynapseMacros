// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Cache Policy

/// Configuration for cache behavior.
public struct CachePolicy: Sendable {
    /// Maximum number of entries in the cache.
    public let maxEntries: Int
    /// Time-to-live for cache entries.
    public let ttl: Duration
    /// Eviction strategy when the cache is full.
    public let eviction: EvictionStrategy

    public init(maxEntries: Int = 100, ttl: Duration = .seconds(300), eviction: EvictionStrategy = .lru) {
        self.maxEntries = maxEntries
        self.ttl = ttl
        self.eviction = eviction
    }
}

/// Cache eviction strategy.
public enum EvictionStrategy: Sendable {
    /// Least Recently Used — evict the entry accessed longest ago.
    case lru
    /// First In, First Out — evict the oldest entry.
    case fifo
}

// MARK: - Generic Cache

/// A generic cache with TTL and configurable eviction.
///
/// All access is serialized via actor isolation for thread safety.
public actor Cache<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let value: Value
        let insertedAt: ContinuousClock.Instant
        var lastAccessed: ContinuousClock.Instant
    }

    private var storage: [Key: Entry] = [:]
    private var insertionOrder: [Key] = []
    private let policy: CachePolicy

    public init(policy: CachePolicy = CachePolicy()) {
        self.policy = policy
    }

    /// Gets a cached value if it exists and hasn't expired.
    public func get(_ key: Key) -> Value? {
        guard var entry = storage[key] else { return nil }

        // Check TTL
        let elapsed = ContinuousClock.now - entry.insertedAt
        if elapsed > policy.ttl {
            storage.removeValue(forKey: key)
            insertionOrder.removeAll { $0 == key }
            return nil
        }

        // Update last accessed for LRU
        entry.lastAccessed = .now
        storage[key] = entry
        return entry.value
    }

    /// Sets a value in the cache.
    public func set(_ key: Key, _ value: Value) {
        // Evict if at capacity
        if storage.count >= policy.maxEntries, storage[key] == nil {
            evict()
        }

        let now = ContinuousClock.now
        storage[key] = Entry(value: value, insertedAt: now, lastAccessed: now)
        if !insertionOrder.contains(key) {
            insertionOrder.append(key)
        }
    }

    /// Removes a specific entry.
    public func invalidate(_ key: Key) {
        storage.removeValue(forKey: key)
        insertionOrder.removeAll { $0 == key }
    }

    /// Clears all entries.
    public func clear() {
        storage.removeAll()
        insertionOrder.removeAll()
    }

    /// Number of entries in the cache.
    public var count: Int { storage.count }

    private func evict() {
        switch policy.eviction {
        case .lru:
            // Find least recently accessed
            guard let lruKey = storage.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else { return }
            storage.removeValue(forKey: lruKey)
            insertionOrder.removeAll { $0 == lruKey }
        case .fifo:
            guard let firstKey = insertionOrder.first else { return }
            storage.removeValue(forKey: firstKey)
            insertionOrder.removeFirst()
        }
    }
}

// MARK: - Tool Result Cache

/// Caches tool execution results to avoid redundant computation.
///
/// Tools opt in to caching via `AgentToolProtocol.isCacheable`. Results are
/// cached by a hash of the tool name and arguments.
public actor ToolResultCache {
    private let cache: Cache<String, String>

    public init(policy: CachePolicy = CachePolicy(maxEntries: 50, ttl: .seconds(300))) {
        self.cache = Cache(policy: policy)
    }

    /// Looks up a cached result for the given tool call.
    public func get(toolName: String, arguments: String) async -> String? {
        let key = Self.cacheKey(toolName: toolName, arguments: arguments)
        return await cache.get(key)
    }

    /// Stores a tool result in the cache.
    public func set(toolName: String, arguments: String, result: String) async {
        let key = Self.cacheKey(toolName: toolName, arguments: arguments)
        await cache.set(key, result)
    }

    /// Invalidates cached results for a specific tool.
    public func invalidate(toolName: String, arguments: String) async {
        let key = Self.cacheKey(toolName: toolName, arguments: arguments)
        await cache.invalidate(key)
    }

    /// Clears all cached results.
    public func clear() async {
        await cache.clear()
    }

    private static func cacheKey(toolName: String, arguments: String) -> String {
        // Simple hash-based key
        let combined = "\(toolName):\(arguments)"
        let hash = combined.utf8.reduce(0) { $0 &+ Int($1) &* 31 }
        return "\(toolName):\(hash)"
    }
}
