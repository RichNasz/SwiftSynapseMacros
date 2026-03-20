// Generated strictly from CodeGenSpecs/Client-Types.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftResponsesDSL

public struct TranscriptEntry: Sendable {
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}
