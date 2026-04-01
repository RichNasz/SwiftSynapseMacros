// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Memory Category

/// Categories for organizing agent memory entries.
public enum MemoryCategory: Codable, Hashable, Sendable {
    /// Information about the user (role, preferences, expertise).
    case user
    /// Guidance on how to approach work (corrections and validated approaches).
    case feedback
    /// Context about ongoing work, goals, initiatives.
    case project
    /// Pointers to external resources and systems.
    case reference
    /// Custom category for domain-specific memory.
    case custom(String)
}

// MARK: - Memory Entry

/// A single persistent memory entry stored across sessions.
///
/// Memory entries persist beyond individual sessions, providing agents
/// with long-term context about users, projects, and learned behaviors.
public struct MemoryEntry: Codable, Sendable, Identifiable {
    /// Unique identifier for this entry.
    public let id: String
    /// The category of this memory.
    public let category: MemoryCategory
    /// The memory content.
    public var content: String
    /// When this entry was created.
    public let createdAt: Date
    /// When this entry was last accessed.
    public var lastAccessedAt: Date
    /// Number of times this entry has been accessed.
    public var accessCount: Int
    /// Tags for filtering and search.
    public var tags: [String]

    public init(
        id: String = UUID().uuidString,
        category: MemoryCategory,
        content: String,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        accessCount: Int = 0,
        tags: [String] = []
    ) {
        self.id = id
        self.category = category
        self.content = content
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.accessCount = accessCount
        self.tags = tags
    }
}

// MARK: - Memory Store Protocol

/// Abstract storage for persistent agent memory.
///
/// Implement this protocol to customize where memories are stored
/// (filesystem, database, cloud, etc.).
public protocol MemoryStore: Sendable {
    /// Saves a memory entry (insert or update).
    func save(_ entry: MemoryEntry) async throws
    /// Retrieves entries by category, ordered by last access (most recent first).
    func retrieve(category: MemoryCategory?, limit: Int) async throws -> [MemoryEntry]
    /// Searches entries by substring match in content or tags.
    func search(query: String, limit: Int) async throws -> [MemoryEntry]
    /// Deletes an entry by id.
    func delete(id: String) async throws
    /// Returns all stored entries.
    func all() async throws -> [MemoryEntry]
    /// Removes all entries.
    func clear() async throws
}

// MARK: - File Memory Store

/// Stores agent memory as JSON files on disk.
///
/// Each memory entry is stored as a separate JSON file in the configured
/// directory (default: `~/.swiftsynapse/memory/`). Files are named by entry id.
public actor FileMemoryStore: MemoryStore {
    private let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.directory = home.appendingPathComponent(".swiftsynapse/memory")
        }
    }

    public init(directoryPath: String) {
        self.directory = URL(fileURLWithPath: directoryPath)
    }

    public func save(_ entry: MemoryEntry) async throws {
        try ensureDirectory()
        let fileURL = directory.appendingPathComponent("\(entry.id).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entry)
        try data.write(to: fileURL)
    }

    public func retrieve(category: MemoryCategory?, limit: Int = 50) async throws -> [MemoryEntry] {
        var entries = try loadAll()
        if let category {
            entries = entries.filter { $0.category == category }
        }
        entries.sort { $0.lastAccessedAt > $1.lastAccessedAt }
        return Array(entries.prefix(limit))
    }

    public func search(query: String, limit: Int = 20) async throws -> [MemoryEntry] {
        let lowered = query.lowercased()
        let entries = try loadAll()
        let matches = entries.filter { entry in
            entry.content.lowercased().contains(lowered)
            || entry.tags.contains { $0.lowercased().contains(lowered) }
        }
        return Array(matches.prefix(limit))
    }

    public func delete(id: String) async throws {
        let fileURL = directory.appendingPathComponent("\(id).json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    public func all() async throws -> [MemoryEntry] {
        try loadAll()
    }

    public func clear() async throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "json" {
            try fileManager.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func ensureDirectory() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func loadAll() throws -> [MemoryEntry] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return files.compactMap { file -> MemoryEntry? in
            guard file.pathExtension == "json" else { return nil }
            guard let data = try? Data(contentsOf: file) else { return nil }
            return try? decoder.decode(MemoryEntry.self, from: data)
        }
    }
}
