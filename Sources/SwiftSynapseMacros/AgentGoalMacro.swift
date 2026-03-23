// Generated strictly from CodeGenSpecs/Macros-AgentGoal.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct AgentGoalMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
              varDecl.bindingSpecifier.tokenKind == .keyword(.let),
              varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) })
        else {
            context.diagnose(.init(
                node: Syntax(node),
                message: AgentGoalDiagnostic.requiresStaticLet
            ))
            return []
        }

        guard let binding = varDecl.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else {
            return []
        }

        let name = pattern.identifier.text

        guard let initializer = binding.initializer?.value,
              let promptValue = extractStringLiteral(from: initializer)
        else {
            context.diagnose(.init(
                node: Syntax(node),
                message: AgentGoalDiagnostic.requiresStringLiteral
            ))
            return []
        }

        // Validate prompt is not empty
        if promptValue.allSatisfy({ $0.isWhitespace || $0.isNewline }) {
            context.diagnose(.init(
                node: Syntax(initializer),
                message: AgentGoalDiagnostic.emptyGoal
            ))
            return []
        }

        // Extract macro arguments
        let args = extractArguments(from: node)

        // Validate maxTurns
        if let maxTurns = args.maxTurns, maxTurns < 1 {
            context.diagnose(.init(
                node: Syntax(node),
                message: AgentGoalDiagnostic.invalidMaxTurns
            ))
            return []
        }

        // Validate temperature
        if let temperature = args.temperature, temperature < 0 || temperature > 2 {
            context.diagnose(.init(
                node: Syntax(node),
                message: AgentGoalDiagnostic.invalidTemperature
            ))
            return []
        }

        // Warn if prompt lacks agentic keywords
        let lowered = promptValue.lowercased()
        let agenticKeywords = ["think step-by-step", "use tools", "final answer"]
        if !agenticKeywords.contains(where: { lowered.contains($0) }) {
            context.diagnose(.init(
                node: Syntax(initializer),
                message: AgentGoalDiagnostic.missingAgenticKeywords
            ))
        }

        let maxTurns = args.maxTurns ?? 20
        let temperature = args.temperature ?? 0.7
        let requiresTools = args.requiresTools ?? false
        let preferredFormat = args.preferredFormat ?? ".text"

        var escaped = ""
        for char in promptValue {
            switch char {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            default: escaped.append(char)
            }
        }

        return [
            """
            static let \(raw: name)_metadata: AgentGoalMetadata = AgentGoalMetadata(
                maxTurns: \(raw: maxTurns),
                temperature: \(raw: temperature),
                requiresTools: \(raw: requiresTools),
                preferredFormat: \(raw: preferredFormat),
                validatedPrompt: "\(raw: escaped)"
            )
            """
        ]
    }

    private struct MacroArguments {
        var maxTurns: Int?
        var temperature: Double?
        var requiresTools: Bool?
        var preferredFormat: String?
    }

    private static func extractArguments(from node: AttributeSyntax) -> MacroArguments {
        var args = MacroArguments()
        guard let argumentList = node.arguments?.as(LabeledExprListSyntax.self) else {
            return args
        }
        for argument in argumentList {
            guard let label = argument.label?.text else { continue }
            switch label {
            case "maxTurns":
                if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                    args.maxTurns = Int(intLiteral.literal.text)
                }
            case "temperature":
                if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                    args.temperature = Double(floatLiteral.literal.text)
                } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                    args.temperature = Double(intLiteral.literal.text)
                }
            case "requiresTools":
                if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                    args.requiresTools = boolLiteral.literal.tokenKind == .keyword(.true)
                }
            case "preferredFormat":
                if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                    args.preferredFormat = ".\(memberAccess.declName.baseName.text)"
                }
            default:
                break
            }
        }
        return args
    }

    private static func extractStringLiteral(from expr: ExprSyntax) -> String? {
        if let stringLiteral = expr.as(StringLiteralExprSyntax.self) {
            return stringLiteral.segments.compactMap { segment -> String? in
                if let stringSegment = segment.as(StringSegmentSyntax.self) {
                    return stringSegment.content.text
                }
                return nil
            }.joined()
        }
        return nil
    }
}

enum AgentGoalDiagnostic: String, DiagnosticMessage {
    case requiresStaticLet
    case requiresStringLiteral
    case emptyGoal
    case invalidMaxTurns
    case invalidTemperature
    case missingAgenticKeywords

    var message: String {
        switch self {
        case .requiresStaticLet:
            return "@AgentGoal can only be applied to a static let declaration"
        case .requiresStringLiteral:
            return "@AgentGoal requires a string literal initializer"
        case .emptyGoal:
            return "Agent goal cannot be empty"
        case .invalidMaxTurns:
            return "maxTurns must be at least 1"
        case .invalidTemperature:
            return "temperature must be between 0 and 2"
        case .missingAgenticKeywords:
            return "Goal may not encourage agentic behavior — consider adding 'think step-by-step' or 'use tools'"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SwiftSynapseMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .missingAgenticKeywords:
            return .warning
        default:
            return .error
        }
    }
}
