// Generated strictly from CodeGenSpecs/Tests.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwiftSynapseMacros)
import SwiftSynapseMacros

let testMacros: [String: Macro.Type] = [
    "SpecDrivenAgent": SpecDrivenAgentMacro.self,
    "StructuredOutput": StructuredOutputMacro.self,
    "Capability": CapabilityMacro.self,
]
#endif

final class MacroExpansionTests: XCTestCase {
    #if canImport(SwiftSynapseMacros)

    // MARK: - @SpecDrivenAgent

    func testSpecDrivenAgentExpandsOnActor() throws {
        assertMacroExpansion(
            """
            @SpecDrivenAgent
            actor MyAgent {
            }
            """,
            expandedSource: """
            actor MyAgent {

                private var _status: AgentStatus = .idle

                private var _transcript: ObservableTranscript = ObservableTranscript()

                var status: AgentStatus {
                    _status
                }

                var transcript: ObservableTranscript {
                    _transcript
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSpecDrivenAgentDiagnosesStruct() throws {
        assertMacroExpansion(
            """
            @SpecDrivenAgent
            struct NotAnActor {
            }
            """,
            expandedSource: """
            struct NotAnActor {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SpecDrivenAgent can only be applied to an actor", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    func testSpecDrivenAgentDiagnosesClass() throws {
        assertMacroExpansion(
            """
            @SpecDrivenAgent
            class NotAnActor {
            }
            """,
            expandedSource: """
            class NotAnActor {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@SpecDrivenAgent can only be applied to an actor", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    func testSpecDrivenAgentUsesActorName() throws {
        assertMacroExpansion(
            """
            @SpecDrivenAgent
            actor CustomBot {
            }
            """,
            expandedSource: """
            actor CustomBot {

                private var _status: AgentStatus = .idle

                private var _transcript: ObservableTranscript = ObservableTranscript()

                var status: AgentStatus {
                    _status
                }

                var transcript: ObservableTranscript {
                    _transcript
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSpecDrivenAgentPublicActorGeneratesPublicAccessors() throws {
        assertMacroExpansion(
            """
            @SpecDrivenAgent
            public actor PublicAgent {
            }
            """,
            expandedSource: """
            public actor PublicAgent {

                private var _status: AgentStatus = .idle

                private var _transcript: ObservableTranscript = ObservableTranscript()

                public var status: AgentStatus {
                    _status
                }

                public var transcript: ObservableTranscript {
                    _transcript
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - @StructuredOutput

    func testStructuredOutputExpandsOnStruct() throws {
        assertMacroExpansion(
            """
            @StructuredOutput
            struct Response {
            }
            """,
            expandedSource: """
            struct Response {

                static var textFormat: TextFormat {
                    .jsonSchema(name: "Response", schema: Self.jsonSchema, strict: true)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testStructuredOutputDiagnosesClass() throws {
        assertMacroExpansion(
            """
            @StructuredOutput
            class NotAStruct {
            }
            """,
            expandedSource: """
            class NotAStruct {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StructuredOutput can only be applied to a struct", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    func testStructuredOutputDiagnosesEnum() throws {
        assertMacroExpansion(
            """
            @StructuredOutput
            enum NotAStruct {
            }
            """,
            expandedSource: """
            enum NotAStruct {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@StructuredOutput can only be applied to a struct", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    // MARK: - @Capability

    func testCapabilityExpandsOnStruct() throws {
        assertMacroExpansion(
            """
            @Capability
            struct Tools {
            }
            """,
            expandedSource: """
            struct Tools {

                func agentTools() -> [AgentToolDefinition] {
                    // TODO: bridge @LLMTool types to AgentToolDefinition
                    []
                }
            }
            """,
            macros: testMacros
        )
    }

    func testCapabilityExpandsOnClass() throws {
        assertMacroExpansion(
            """
            @Capability
            class Tools {
            }
            """,
            expandedSource: """
            class Tools {

                func agentTools() -> [AgentToolDefinition] {
                    // TODO: bridge @LLMTool types to AgentToolDefinition
                    []
                }
            }
            """,
            macros: testMacros
        )
    }

    func testCapabilityDiagnosesActor() throws {
        assertMacroExpansion(
            """
            @Capability
            actor Foo {
            }
            """,
            expandedSource: """
            actor Foo {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Capability can only be applied to a struct or class", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    func testCapabilityDiagnosesEnum() throws {
        assertMacroExpansion(
            """
            @Capability
            enum Foo {
            }
            """,
            expandedSource: """
            enum Foo {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Capability can only be applied to a struct or class", line: 1, column: 1),
            ],
            macros: testMacros
        )
    }

    #else
    func testMacrosNotAvailable() throws {
        XCTFail("SwiftSynapseMacros module not available — cannot run macro expansion tests")
    }
    #endif
}
