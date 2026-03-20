// Generated from CodeGenSpecs/Overview.md — Do not edit manually. Update spec and re-generate.
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
