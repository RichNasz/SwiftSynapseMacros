// Generated from CodeGenSpecs/Client-Types.md — Do not edit manually. Update spec and re-generate.
import SwiftResponsesDSL

public struct TranscriptEntry: Sendable {
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
