// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

/// A list-based permission policy for simple allow/deny/approval rules.
///
/// ```swift
/// let policy = ToolListPolicy(rules: [
///     .deny(["deleteDatabase", "dropTable"]),
///     .requireApproval(["chargeCard", "sendEmail"]),
///     .allow(["lookupCustomer", "getOrderStatus"])
/// ])
/// ```
///
/// Rules are evaluated in order. The first matching rule wins.
/// If no rule matches, the tool is allowed by default.
public struct ToolListPolicy: PermissionPolicy {
    /// A permission rule for a set of tool names.
    public enum Rule: Sendable {
        /// Only these tools are explicitly allowed.
        case allow([String])
        /// These tools are blocked from execution.
        case deny([String])
        /// These tools require explicit approval before execution.
        case requireApproval([String])
    }

    private let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }

    public func evaluate(toolName: String, arguments: String) async -> ToolPermission {
        for rule in rules {
            switch rule {
            case .deny(let names) where names.contains(toolName):
                return .denied(reason: "Tool '\(toolName)' is denied by policy")
            case .requireApproval(let names) where names.contains(toolName):
                return .requiresApproval(reason: "Tool '\(toolName)' requires approval")
            case .allow(let names) where names.contains(toolName):
                return .allowed
            default:
                continue
            }
        }
        return .allowed
    }
}
