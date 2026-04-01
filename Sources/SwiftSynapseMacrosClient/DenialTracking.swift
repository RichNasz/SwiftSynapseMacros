// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Permission Mode

/// Configures the overall permission behavior for an agent.
public enum PermissionMode: String, Codable, Sendable {
    /// Policy-driven: evaluate permission rules normally.
    case `default`
    /// Auto-approve all tool executions (trusted environments).
    case autoApprove
    /// Always prompt for approval regardless of policy.
    case alwaysPrompt
    /// Block all tool execution; return proposed actions instead.
    case planOnly
}

// MARK: - Denial Tracker

/// Tracks consecutive tool execution denials per tool.
///
/// When a tool is denied more than `threshold` consecutive times,
/// the tracker signals that the agent should switch behavior
/// (e.g., stop requesting the tool or escalate to the user).
public actor DenialTracker {
    private var denialCounts: [String: Int] = [:]
    /// Number of consecutive denials before triggering mode switch.
    public let threshold: Int

    public init(threshold: Int = 3) {
        self.threshold = threshold
    }

    /// Records a denial for the given tool.
    public func recordDenial(toolName: String) {
        denialCounts[toolName, default: 0] += 1
    }

    /// Records a successful execution, resetting the denial count for the tool.
    public func recordSuccess(toolName: String) {
        denialCounts.removeValue(forKey: toolName)
    }

    /// Whether the tool has exceeded the denial threshold.
    public func isThresholdExceeded(toolName: String) -> Bool {
        (denialCounts[toolName] ?? 0) >= threshold
    }

    /// Current consecutive denial count for a tool.
    public func denialCount(for toolName: String) -> Int {
        denialCounts[toolName] ?? 0
    }

    /// Resets all denial counts.
    public func reset() {
        denialCounts.removeAll()
    }
}

// MARK: - Adaptive Permission Gate

/// Wraps a `PermissionGate` with denial tracking and mode awareness.
///
/// Integrates `DenialTracker` and `PermissionMode` to provide adaptive
/// permission behavior:
/// - In `autoApprove` mode, all tools are allowed without checking policies
/// - In `alwaysPrompt` mode, approval is always requested
/// - In `planOnly` mode, all tools are denied with an explanation
/// - In `default` mode, policies are checked normally, with denial tracking
public actor AdaptivePermissionGate {
    private let gate: PermissionGate
    private let tracker: DenialTracker
    public let mode: PermissionMode

    public init(gate: PermissionGate, mode: PermissionMode = .default, denialThreshold: Int = 3) {
        self.gate = gate
        self.tracker = DenialTracker(threshold: denialThreshold)
        self.mode = mode
    }

    /// Checks permission for a tool, respecting the current mode and denial history.
    public func check(toolName: String, arguments: String) async throws {
        switch mode {
        case .autoApprove:
            return // Always allowed

        case .planOnly:
            throw PermissionError.denied(
                tool: toolName,
                reason: "Agent is in plan-only mode. Tool execution is not permitted."
            )

        case .alwaysPrompt:
            // Force approval regardless of policy
            try await gate.check(toolName: toolName, arguments: arguments)

        case .default:
            // Check if denial threshold exceeded — force prompt mode
            if await tracker.isThresholdExceeded(toolName: toolName) {
                throw PermissionError.denied(
                    tool: toolName,
                    reason: "Tool '\(toolName)' has been denied \(await tracker.denialCount(for: toolName)) consecutive times."
                )
            }

            do {
                try await gate.check(toolName: toolName, arguments: arguments)
                await tracker.recordSuccess(toolName: toolName)
            } catch {
                await tracker.recordDenial(toolName: toolName)
                throw error
            }
        }
    }
}
