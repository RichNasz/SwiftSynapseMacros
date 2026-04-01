// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Guardrail Types

/// The kind of content being evaluated by a guardrail.
public enum GuardrailInput: Sendable {
    /// Tool arguments about to be passed to a tool.
    case toolArguments(toolName: String, arguments: String)
    /// Text output from the LLM.
    case llmOutput(text: String)
    /// User input before processing.
    case userInput(text: String)
}

/// The decision returned by a guardrail policy.
public enum GuardrailDecision: Sendable {
    /// Allow the content through unchanged.
    case allow
    /// Replace the content with a sanitized version.
    case sanitize(replacement: String)
    /// Block the content entirely with a reason.
    case block(reason: String)
    /// Allow but emit a warning.
    case warn(reason: String)
}

/// Risk level associated with a guardrail trigger, used for telemetry.
public enum RiskLevel: String, Sendable, Codable {
    case low
    case medium
    case high
    case critical
}

// MARK: - Guardrail Policy Protocol

/// A policy that evaluates content for safety before or after processing.
///
/// Implement this protocol to add input sanitization, output filtering,
/// PII detection, or content safety checks to agents.
public protocol GuardrailPolicy: Sendable {
    /// A descriptive name for this policy (used in telemetry).
    var name: String { get }

    /// Evaluates the input and returns a decision.
    func evaluate(input: GuardrailInput) async -> GuardrailDecision
}

// MARK: - Content Filter

/// A configurable regex-based content filter for detecting sensitive patterns.
///
/// Ships with default patterns for credit card numbers, SSNs, and API keys.
/// Add custom patterns via `addPattern(_:name:risk:)`.
public struct ContentFilter: GuardrailPolicy, Sendable {
    public let name: String

    /// A pattern to detect in content.
    public struct Pattern: Sendable {
        public let name: String
        public let regex: String
        public let risk: RiskLevel
        public let action: GuardrailDecision

        public init(name: String, regex: String, risk: RiskLevel, action: GuardrailDecision = .block(reason: "")) {
            self.name = name
            self.regex = regex
            self.risk = risk
            // If action reason is empty, auto-fill with pattern name
            if case .block(let reason) = action, reason.isEmpty {
                self.action = .block(reason: "Content matched sensitive pattern: \(name)")
            } else {
                self.action = action
            }
        }
    }

    private let patterns: [Pattern]

    /// Creates a content filter with default patterns for common sensitive data.
    public static var `default`: ContentFilter {
        ContentFilter(name: "DefaultContentFilter", patterns: [
            Pattern(
                name: "credit_card",
                regex: #"\b(?:\d[ -]*?){13,16}\b"#,
                risk: .high
            ),
            Pattern(
                name: "ssn",
                regex: #"\b\d{3}-\d{2}-\d{4}\b"#,
                risk: .critical
            ),
            Pattern(
                name: "api_key_generic",
                regex: #"(?i)(?:api[_-]?key|apikey|secret[_-]?key|access[_-]?token)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{20,}['\"]?"#,
                risk: .high
            ),
            Pattern(
                name: "bearer_token",
                regex: #"(?i)bearer\s+[A-Za-z0-9_\-\.]{20,}"#,
                risk: .high
            ),
        ])
    }

    /// Creates a content filter with custom patterns.
    public init(name: String = "ContentFilter", patterns: [Pattern]) {
        self.name = name
        self.patterns = patterns
    }

    public func evaluate(input: GuardrailInput) async -> GuardrailDecision {
        let text: String
        switch input {
        case .toolArguments(_, let args): text = args
        case .llmOutput(let t): text = t
        case .userInput(let t): text = t
        }

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern.regex) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                return pattern.action
            }
        }
        return .allow
    }
}

// MARK: - Guardrail Pipeline

/// Evaluates content through an ordered list of guardrail policies.
///
/// Policies are evaluated in registration order. The most restrictive decision wins:
/// `.block` > `.sanitize` > `.warn` > `.allow`.
public actor GuardrailPipeline {
    private var policies: [any GuardrailPolicy] = []

    public init() {}

    /// Adds a guardrail policy to the pipeline.
    public func add(_ policy: any GuardrailPolicy) {
        policies.append(policy)
    }

    /// Evaluates all policies and returns the most restrictive decision.
    public func evaluate(input: GuardrailInput) async -> (decision: GuardrailDecision, policy: String?) {
        var mostRestrictive: GuardrailDecision = .allow
        var triggeringPolicy: String? = nil

        for policy in policies {
            let decision = await policy.evaluate(input: input)
            if severity(of: decision) > severity(of: mostRestrictive) {
                mostRestrictive = decision
                triggeringPolicy = policy.name
            }
        }

        return (mostRestrictive, triggeringPolicy)
    }

    private func severity(of decision: GuardrailDecision) -> Int {
        switch decision {
        case .allow: 0
        case .warn: 1
        case .sanitize: 2
        case .block: 3
        }
    }
}

/// Errors from guardrail enforcement.
public enum GuardrailError: Error, Sendable {
    /// A guardrail policy blocked the content.
    case blocked(policy: String, reason: String)
}
