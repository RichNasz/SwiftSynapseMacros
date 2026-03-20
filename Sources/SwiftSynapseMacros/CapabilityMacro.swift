// Generated from CodeGenSpecs/Macros-Capability.md — Do not edit manually. Update spec and re-generate.
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CapabilityMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) || declaration.is(ClassDeclSyntax.self) else {
            context.diagnose(.init(
                node: Syntax(node),
                message: CapabilityDiagnostic.requiresStructOrClass
            ))
            return []
        }

        return [
            """
            func agentTools() -> [AgentTool] {
                // TODO: bridge @LLMTool types to AgentTool
                []
            }
            """,
        ]
    }
}

enum CapabilityDiagnostic: String, DiagnosticMessage {
    case requiresStructOrClass

    var message: String {
        switch self {
        case .requiresStructOrClass:
            return "@Capability can only be applied to a struct or class"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SwiftSynapseMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
