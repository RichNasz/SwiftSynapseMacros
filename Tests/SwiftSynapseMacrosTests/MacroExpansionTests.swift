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

                private var _client: LLMClient?

                var status: AgentStatus {
                    _status
                }

                var transcript: ObservableTranscript {
                    _transcript
                }

                var client: LLMClient {
                    guard let c = _client else {
                        fatalError("LLMClient not configured. Call configure(client:) before accessing.")
                    }
                    return c
                }

                func configure(client: LLMClient) {
                    _client = client
                }

                func run(goal: String) async throws {
                    guard let c = _client else {
                        throw SwiftSynapseError.clientNotInjected
                    }
                    _status = .running
                    do {
                        let result = try await AgentRuntime.execute(goal: goal, transcript: _transcript, client: c)
                        _status = .completed(result)
                    } catch {
                        _status = .error(error)
                        throw error
                    }
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

                private var _client: LLMClient?

                var status: AgentStatus {
                    _status
                }

                var transcript: ObservableTranscript {
                    _transcript
                }

                var client: LLMClient {
                    guard let c = _client else {
                        fatalError("LLMClient not configured. Call configure(client:) before accessing.")
                    }
                    return c
                }

                func configure(client: LLMClient) {
                    _client = client
                }

                func run(goal: String) async throws {
                    guard let c = _client else {
                        throw SwiftSynapseError.clientNotInjected
                    }
                    _status = .running
                    do {
                        let result = try await AgentRuntime.execute(goal: goal, transcript: _transcript, client: c)
                        _status = .completed(result)
                    } catch {
                        _status = .error(error)
                        throw error
                    }
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

                func agentTools() -> [AgentTool] {
                    // TODO: bridge @LLMTool types to AgentTool
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

                func agentTools() -> [AgentTool] {
                    // TODO: bridge @LLMTool types to AgentTool
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
