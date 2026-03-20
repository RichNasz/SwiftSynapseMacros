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
            """
            enum Status: String, Sendable {
                case idle, running, completed, failed
            }
            """,
            "private var _status: Status = .idle",
            "private var _transcript: [TranscriptEntry] = []",
            "private var _dslAgent: LLMClient?",
            """
            var status: Status {
                _status
            }
            """,
            """
            var isRunning: Bool {
                _status == .running
            }
            """,
            """
            var transcript: [TranscriptEntry] {
                _transcript
            }
            """,
            "var client: LLMClient?",
            """
            func run(_ message: String) async throws -> String {
                guard let client else {
                    throw SwiftSynapseError.clientNotInjected
                }
                _status = .running
                do {
                    let response = try await client.chat(model: "gpt-4o", message: message)
                    let result = response.assistantMessages.first?.content.first.flatMap {
                        if case .text(let text) = $0 { return text }
                        return nil
                    } ?? ""
                    _transcript.append(TranscriptEntry(role: .user, content: message))
                    _transcript.append(TranscriptEntry(role: .assistant, content: result))
                    _status = .completed
                    return result
                } catch {
                    _status = .failed
                    throw error
                }
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
