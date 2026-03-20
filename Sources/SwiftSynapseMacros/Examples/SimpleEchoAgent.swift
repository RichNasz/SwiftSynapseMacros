// ===----------------------------------------------------------------------===//
// This file is excluded from the build (see Package.swift `exclude`).
// It serves as a usage reference for the SwiftSynapseMacros API.
// ===----------------------------------------------------------------------===//

/*

import SwiftSynapseMacrosClient

@SpecDrivenAgent
actor EchoAgent {
    // The macro generates:
    //   enum Status: String, Sendable { case idle, running, completed, failed }
    //   private var _status: Status
    //   private var _transcript: [TranscriptEntry]
    //   private var _dslAgent: LLMClient?
    //   var status: Status
    //   var isRunning: Bool
    //   var transcript: [TranscriptEntry]
    //   var client: LLMClient?
    //   func run(_ message: String) async throws -> String
}

@StructuredOutput
struct EchoResponse {
    let message: String
    // The macro generates:
    //   static var textFormat: TextFormat
    // which bridges Self.jsonSchema (from @LLMToolArguments) to TextFormat
}

@Capability
struct EchoCapability {
    // The macro generates:
    //   func agentTools() -> [AgentTool]
    // which bridges @LLMTool types to AgentTool instances
}

*/
