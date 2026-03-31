// Generated from CodeGenSpecs/Client-Types.md — Do not edit manually. Update spec and re-generate.

public enum AgentStatus: @unchecked Sendable {
    case idle
    case running
    case paused
    case error(Error)
    case completed(String)
}
