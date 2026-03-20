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

                enum Status: String, Sendable {
                    case idle, running, completed, failed
                }

                private var _status: Status = .idle

                private var _transcript: [TranscriptEntry] = []

                private var _dslAgent: LLMClient?

                var status: Status {
                    _status
                }

                var isRunning: Bool {
                    _status == .running
                }

                var transcript: [TranscriptEntry] {
                    _transcript
                }

                var client: LLMClient?

                func run(_ message: String) async throws -> String {
                    guard let client else {
                        throw SwiftSynapseError.clientNotInjected
                    }
                    _status = .running
                    do {
                        let response = try await client.chat(model: "gpt-4o", message: message)
                        let result = response.assistantMessages.first?.content.first.flatMap {
                            if case .text(let text) = $0 {
                                return text
                            }
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

    #else
    func testMacrosNotAvailable() throws {
        XCTFail("SwiftSynapseMacros module not available — cannot run macro expansion tests")
    }
    #endif
}
