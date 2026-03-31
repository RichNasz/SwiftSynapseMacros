// Generated strictly from CodeGenSpecs/Macros-SpecDrivenAgent.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SpecDrivenAgentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(ActorDeclSyntax.self) else {
            context.diagnose(.init(
                node: Syntax(node),
                message: SpecDrivenAgentDiagnostic.requiresActor
            ))
            return []
        }

        return [
            "private var _status: AgentStatus = .idle",
            "private var _transcript: ObservableTranscript = ObservableTranscript()",
            """
            var status: AgentStatus {
                _status
            }
            """,
            """
            var transcript: ObservableTranscript {
                _transcript
            }
            """,
        ]
    }
}

enum SpecDrivenAgentDiagnostic: String, DiagnosticMessage {
    case requiresActor

    var message: String {
        switch self {
        case .requiresActor:
            return "@SpecDrivenAgent can only be applied to an actor"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SwiftSynapseMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
