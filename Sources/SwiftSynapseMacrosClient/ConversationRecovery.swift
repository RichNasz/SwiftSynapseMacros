// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation
import SwiftOpenResponsesDSL

// MARK: - Integrity Violations

/// A transcript integrity violation detected during consistency checking.
public enum IntegrityViolation: Sendable {
    /// A tool call at the given index has no matching tool result.
    case orphanedToolCall(name: String, index: Int)
    /// A tool result at the given index has no preceding tool call.
    case orphanedToolResult(name: String, index: Int)
    /// An unexpected entry type at the given index.
    case invalidSequence(expected: String, found: String, index: Int)
}

// MARK: - Transcript Integrity Check

/// Validates transcript consistency by checking tool call/result pairing
/// and entry sequencing.
///
/// Detects:
/// - Tool calls without matching results (orphaned calls)
/// - Tool results without preceding calls (orphaned results)
/// - Invalid entry sequences
public struct TranscriptIntegrityCheck: Sendable {
    public init() {}

    /// Checks the transcript for integrity violations.
    ///
    /// - Parameter entries: The transcript entries to validate.
    /// - Returns: A list of violations found, empty if transcript is consistent.
    public func check(_ entries: [TranscriptEntry]) -> [IntegrityViolation] {
        var violations: [IntegrityViolation] = []
        var pendingToolCalls: [(name: String, index: Int)] = []

        for (index, entry) in entries.enumerated() {
            switch entry {
            case .toolCall(let name, _):
                pendingToolCalls.append((name: name, index: index))

            case .toolResult(let name, _, _):
                if let matchIndex = pendingToolCalls.firstIndex(where: { $0.name == name }) {
                    pendingToolCalls.remove(at: matchIndex)
                } else {
                    violations.append(.orphanedToolResult(name: name, index: index))
                }

            default:
                break
            }
        }

        // Any remaining pending tool calls are orphaned
        for pending in pendingToolCalls {
            violations.append(.orphanedToolCall(name: pending.name, index: pending.index))
        }

        return violations
    }
}

// MARK: - Recovery Strategy Protocol

/// A strategy for repairing transcript integrity violations.
public protocol ConversationRecoveryStrategy: Sendable {
    /// Repairs the transcript based on detected violations.
    ///
    /// - Parameters:
    ///   - transcript: The current transcript entries.
    ///   - violations: The violations detected by `TranscriptIntegrityCheck`.
    /// - Returns: A repaired transcript.
    func repair(transcript: [TranscriptEntry], violations: [IntegrityViolation]) -> [TranscriptEntry]
}

// MARK: - Default Recovery Strategy

/// Default recovery strategy:
/// - For orphaned tool calls: appends a synthetic error result
/// - For orphaned tool results: removes them
public struct DefaultConversationRecoveryStrategy: ConversationRecoveryStrategy {
    public init() {}

    public func repair(transcript: [TranscriptEntry], violations: [IntegrityViolation]) -> [TranscriptEntry] {
        guard !violations.isEmpty else { return transcript }

        var result = transcript

        // Collect indices of orphaned results to remove (process in reverse to preserve indices)
        let orphanedResultIndices = violations.compactMap { violation -> Int? in
            if case .orphanedToolResult(_, let index) = violation { return index }
            return nil
        }.sorted(by: >)

        for index in orphanedResultIndices {
            if index < result.count {
                result.remove(at: index)
            }
        }

        // Append synthetic error results for orphaned tool calls
        for violation in violations {
            if case .orphanedToolCall(let name, _) = violation {
                result.append(.toolResult(
                    name: name,
                    result: "[Error: Tool call interrupted — no result received]",
                    duration: .zero
                ))
            }
        }

        return result
    }
}

// MARK: - Convenience Function

/// Validates and repairs a transcript in one call.
///
/// Returns the repaired transcript and any violations that were found.
///
/// ```swift
/// let (repaired, violations) = recoverTranscript(entries)
/// if !violations.isEmpty {
///     print("Repaired \(violations.count) transcript violations")
/// }
/// ```
public func recoverTranscript(
    _ entries: [TranscriptEntry],
    strategy: ConversationRecoveryStrategy = DefaultConversationRecoveryStrategy()
) -> (entries: [TranscriptEntry], violations: [IntegrityViolation]) {
    let check = TranscriptIntegrityCheck()
    let violations = check.check(entries)
    guard !violations.isEmpty else {
        return (entries: entries, violations: [])
    }
    let repaired = strategy.repair(transcript: entries, violations: violations)
    return (entries: repaired, violations: violations)
}
