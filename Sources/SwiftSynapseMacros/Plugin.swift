import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftSynapseMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        SpecDrivenAgentMacro.self,
        StructuredOutputMacro.self,
        CapabilityMacro.self,
    ]
}
