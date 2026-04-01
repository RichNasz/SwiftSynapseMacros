// Generated from CodeGenSpecs/Client-Types.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Tool Progress Update

/// A progress update emitted by a tool during execution.
///
/// Tools conforming to `ProgressReportingTool` emit these updates via the
/// `ToolProgressDelegate` to provide real-time feedback during long-running operations.
public struct ToolProgressUpdate: Sendable {
    /// The tool call ID this update belongs to.
    public let callId: String
    /// The name of the tool emitting progress.
    public let toolName: String
    /// A human-readable progress message.
    public let message: String
    /// Optional fraction complete (0.0–1.0). Nil for indeterminate progress.
    public let fractionComplete: Double?
    /// Optional tool-specific metadata (e.g., bytes transferred, rows processed).
    public let metadata: [String: String]

    public init(
        callId: String,
        toolName: String,
        message: String,
        fractionComplete: Double? = nil,
        metadata: [String: String] = [:]
    ) {
        self.callId = callId
        self.toolName = toolName
        self.message = message
        self.fractionComplete = fractionComplete
        self.metadata = metadata
    }
}
