// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

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

// MARK: - Tool Progress Delegate

/// A delegate that receives progress updates from tools during execution.
///
/// Implement this protocol to display progress bars, update UI, or log progress.
public protocol ToolProgressDelegate: Sendable {
    func reportProgress(_ update: ToolProgressUpdate) async
}

// MARK: - Progress-Reporting Tool Protocol

/// A refinement of `AgentToolProtocol` for tools that emit progress during execution.
///
/// Tools conforming to this protocol receive a `ToolProgressDelegate` during execution,
/// allowing them to report intermediate progress for long-running operations.
///
/// ```swift
/// struct DataImportTool: ProgressReportingTool {
///     // ...
///     func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output {
///         for (i, batch) in batches.enumerated() {
///             await progress.reportProgress(ToolProgressUpdate(
///                 callId: callId,
///                 toolName: Self.name,
///                 message: "Importing batch \(i+1)/\(batches.count)",
///                 fractionComplete: Double(i+1) / Double(batches.count)
///             ))
///             try await processBatch(batch)
///         }
///         return .success
///     }
/// }
/// ```
public protocol ProgressReportingTool: AgentToolProtocol {
    /// Executes the tool with progress reporting.
    func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output
}

extension ProgressReportingTool {
    /// Default implementation bridges to the progress-aware version with a no-op delegate.
    public func execute(input: Input) async throws -> Output {
        try await execute(input: input, callId: "", progress: NoOpProgressDelegate())
    }
}

/// A no-op progress delegate used when no delegate is provided.
struct NoOpProgressDelegate: ToolProgressDelegate {
    func reportProgress(_ update: ToolProgressUpdate) async {}
}
