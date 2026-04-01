// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Session Metadata

/// Lightweight summary of a saved session for listing without loading full transcripts.
public struct SessionMetadata: Codable, Sendable, Identifiable {
    public let id: String
    public let agentType: String
    public let goal: String
    public let createdAt: Date
    public let savedAt: Date
    public let status: SessionStatus

    public init(
        id: String,
        agentType: String,
        goal: String,
        createdAt: Date,
        savedAt: Date,
        status: SessionStatus
    ) {
        self.id = id
        self.agentType = agentType
        self.goal = goal
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.status = status
    }
}

/// The persistence status of a saved session.
public enum SessionStatus: String, Codable, Sendable {
    case active
    case paused
    case completed
    case failed
}

// MARK: - Session Store Protocol

/// Abstract persistence backend for agent sessions.
///
/// Implement this protocol to save sessions to disk, a database, iCloud, etc.
/// The framework provides `FileSessionStore` as a default file-based implementation.
public protocol SessionStore: Sendable {
    /// Saves or updates a session.
    func save(_ session: AgentSession) async throws

    /// Loads a session by ID. Returns nil if not found.
    func load(sessionId: String) async throws -> AgentSession?

    /// Lists metadata for all saved sessions, most recent first.
    func list() async throws -> [SessionMetadata]

    /// Deletes a session by ID. No-op if not found.
    func delete(sessionId: String) async throws
}

// MARK: - File Session Store

/// A file-based `SessionStore` that writes one JSON file per session.
///
/// Sessions are stored as `{sessionId}.json` in a configurable directory.
/// The directory is created automatically if it doesn't exist.
public actor FileSessionStore: SessionStore {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a file session store.
    /// - Parameter directory: The directory to store session files in.
    ///   Defaults to `~/.swiftsynapse/sessions/`.
    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftsynapse/sessions", isDirectory: true)
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private func fileURL(for sessionId: String) -> URL {
        directory.appendingPathComponent("\(sessionId).json")
    }

    public func save(_ session: AgentSession) async throws {
        try ensureDirectory()
        let data = try encoder.encode(session)
        try data.write(to: fileURL(for: session.sessionId), options: .atomic)
    }

    public func load(sessionId: String) async throws -> AgentSession? {
        let url = fileURL(for: sessionId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(AgentSession.self, from: data)
    }

    public func list() async throws -> [SessionMetadata] {
        try ensureDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "json" }

        var metadata: [SessionMetadata] = []
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let session = try? decoder.decode(AgentSession.self, from: data) else {
                continue
            }
            let status: SessionStatus
            switch session.completedStepIndex {
            case _ where session.completedStepIndex < 0: status = .failed
            default: status = .completed
            }
            metadata.append(SessionMetadata(
                id: session.sessionId,
                agentType: session.agentType,
                goal: session.goal,
                createdAt: session.createdAt,
                savedAt: session.savedAt,
                status: status
            ))
        }
        return metadata.sorted { $0.savedAt > $1.savedAt }
    }

    public func delete(sessionId: String) async throws {
        let url = fileURL(for: sessionId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
