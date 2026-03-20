// Generated strictly from CodeGenSpecs/Overview.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
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
