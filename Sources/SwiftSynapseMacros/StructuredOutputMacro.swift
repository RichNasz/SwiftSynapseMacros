// Generated from CodeGenSpecs/Macros-StructuredOutput.md — Do not edit manually. Update spec and re-generate.
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct StructuredOutputMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(.init(
                node: Syntax(node),
                message: StructuredOutputDiagnostic.requiresStruct
            ))
            return []
        }

        let typeName = structDecl.name.trimmedDescription

        return [
            """
            static var textFormat: TextFormat {
                .jsonSchema(name: "\(raw: typeName)", schema: Self.jsonSchema, strict: true)
            }
            """,
        ]
    }
}

enum StructuredOutputDiagnostic: String, DiagnosticMessage {
    case requiresStruct

    var message: String {
        switch self {
        case .requiresStruct:
            return "@StructuredOutput can only be applied to a struct"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SwiftSynapseMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
