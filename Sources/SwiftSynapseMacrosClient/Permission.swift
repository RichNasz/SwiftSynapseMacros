// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Permission Decision

/// The result of evaluating a tool permission policy.
public enum ToolPermission: Sendable {
    /// The tool is allowed to execute.
    case allowed
    /// The tool requires explicit approval before execution.
    case requiresApproval(reason: String)
    /// The tool is denied and must not execute.
    case denied(reason: String)
}

// MARK: - Permission Policy

/// Evaluates whether a tool call is permitted.
///
/// Implement this protocol to enforce access control, compliance rules,
/// or operational constraints on tool execution.
public protocol PermissionPolicy: Sendable {
    /// Evaluates whether a tool call is permitted.
    ///
    /// - Parameters:
    ///   - toolName: The name of the tool being invoked.
    ///   - arguments: The JSON-encoded arguments to the tool.
    /// - Returns: The permission decision.
    func evaluate(toolName: String, arguments: String) async -> ToolPermission
}

// MARK: - Approval Delegate

/// Handles human-in-the-loop approval for tool calls that require it.
///
/// Implement this protocol to present approval UI (alerts, confirmation dialogs,
/// Slack messages, etc.) when a tool requires explicit approval.
public protocol ApprovalDelegate: Sendable {
    /// Requests approval for a tool call.
    ///
    /// - Parameters:
    ///   - toolName: The tool requesting approval.
    ///   - arguments: The JSON-encoded arguments.
    ///   - reason: Why approval is required.
    /// - Returns: `true` if approved, `false` if rejected.
    func requestApproval(toolName: String, arguments: String, reason: String) async -> Bool
}

// MARK: - Permission Gate

/// Evaluates registered policies and handles approval flow for tool calls.
///
/// The gate evaluates all registered policies in order. The most restrictive
/// decision wins: `.denied` > `.requiresApproval` > `.allowed`.
///
/// ```swift
/// let gate = PermissionGate()
/// await gate.addPolicy(ToolListPolicy(rules: [
///     .requireApproval(["chargeCard", "sendEmail"]),
///     .deny(["deleteAccount"])
/// ]))
/// await gate.setApprovalDelegate(myUIDelegate)
/// ```
public actor PermissionGate {
    private var policies: [any PermissionPolicy] = []
    private var approvalDelegate: (any ApprovalDelegate)?

    public init() {}

    /// Adds a permission policy to the gate.
    public func addPolicy(_ policy: any PermissionPolicy) {
        policies.append(policy)
    }

    /// Sets the delegate responsible for handling approval requests.
    public func setApprovalDelegate(_ delegate: any ApprovalDelegate) {
        self.approvalDelegate = delegate
    }

    /// Checks all policies for a tool call. Throws if denied or if approval is rejected.
    ///
    /// Evaluates all policies. If any policy denies, throws immediately.
    /// If any policy requires approval, invokes the approval delegate.
    public func check(toolName: String, arguments: String) async throws {
        var needsApproval: String? = nil

        for policy in policies {
            let permission = await policy.evaluate(toolName: toolName, arguments: arguments)
            switch permission {
            case .allowed:
                continue
            case .denied(let reason):
                throw PermissionError.denied(tool: toolName, reason: reason)
            case .requiresApproval(let reason):
                needsApproval = reason
            }
        }

        if let reason = needsApproval {
            guard let delegate = approvalDelegate else {
                throw PermissionError.noApprovalDelegate(tool: toolName)
            }
            let approved = await delegate.requestApproval(
                toolName: toolName,
                arguments: arguments,
                reason: reason
            )
            guard approved else {
                throw PermissionError.rejected(tool: toolName)
            }
        }
    }
}

// MARK: - Permission Errors

/// Errors from the permission system.
public enum PermissionError: Error, Sendable {
    /// A policy explicitly denied the tool call.
    case denied(tool: String, reason: String)
    /// The tool requires approval but no `ApprovalDelegate` is configured.
    case noApprovalDelegate(tool: String)
    /// The approval delegate rejected the tool call.
    case rejected(tool: String)
}
