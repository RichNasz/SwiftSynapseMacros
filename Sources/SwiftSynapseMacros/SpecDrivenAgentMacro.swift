// Generated strictly from CodeGenSpecs/Macros-SpecDrivenAgent.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct SpecDrivenAgentMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(ActorDeclSyntax.self) else { return [] }
        let ext: DeclSyntax = "extension \(type.trimmed): AgentExecutable {}"
        return [ext.cast(ExtensionDeclSyntax.self)]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let actorDecl = declaration.as(ActorDeclSyntax.self) else {
            context.diagnose(.init(
                node: Syntax(node),
                message: SpecDrivenAgentDiagnostic.requiresActor
            ))
            return []
        }

        let isPublic = actorDecl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
        let access = isPublic ? "public " : ""

        return [
            "\(raw: access)var _status: AgentStatus = .idle",
            "\(raw: access)var _transcript: ObservableTranscript = ObservableTranscript()",
            """
            \(raw: access)var status: AgentStatus {
                _status
            }
            """,
            """
            \(raw: access)var transcript: ObservableTranscript {
                _transcript
            }
            """,
            """
            \(raw: access)func run(goal: String) async throws -> String {
                try await agentRun(agent: self, goal: goal)
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
