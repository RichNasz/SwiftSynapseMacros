// Generated strictly from CodeGenSpecs/Macros-AgentGoal.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(SwiftSynapseMacros)
import SwiftSynapseMacros

let agentGoalMacros: [String: Macro.Type] = [
    "AgentGoal": AgentGoalMacro.self,
]
#endif

final class AgentGoalMacroTests: XCTestCase {
    #if canImport(SwiftSynapseMacros)

    func testAgentGoalExpandsOnStaticLet() throws {
        assertMacroExpansion(
            """
            @AgentGoal
            static let goal = "Think step-by-step. Use tools when needed."
            """,
            expandedSource: """
            static let goal = "Think step-by-step. Use tools when needed."

            static let goal_metadata: AgentGoalMetadata = AgentGoalMetadata(
                maxTurns: 20,
                temperature: 0.7,
                requiresTools: false,
                preferredFormat: .text,
                validatedPrompt: "Think step-by-step. Use tools when needed."
            )
            """,
            macros: agentGoalMacros
        )
    }

    func testAgentGoalWithParameters() throws {
        assertMacroExpansion(
            """
            @AgentGoal(maxTurns: 10, temperature: 0.5)
            static let goal = "Think step-by-step."
            """,
            expandedSource: """
            static let goal = "Think step-by-step."

            static let goal_metadata: AgentGoalMetadata = AgentGoalMetadata(
                maxTurns: 10,
                temperature: 0.5,
                requiresTools: false,
                preferredFormat: .text,
                validatedPrompt: "Think step-by-step."
            )
            """,
            macros: agentGoalMacros
        )
    }

    func testAgentGoalDiagnosesEmptyPrompt() throws {
        assertMacroExpansion(
            """
            @AgentGoal
            static let goal = ""
            """,
            expandedSource: """
            static let goal = ""
            """,
            diagnostics: [
                DiagnosticSpec(message: "Agent goal cannot be empty", line: 2, column: 19),
            ],
            macros: agentGoalMacros
        )
    }

    func testAgentGoalDiagnosesNonStaticLet() throws {
        assertMacroExpansion(
            """
            @AgentGoal
            var goal = "Think step-by-step."
            """,
            expandedSource: """
            var goal = "Think step-by-step."
            """,
            diagnostics: [
                DiagnosticSpec(message: "@AgentGoal can only be applied to a static let declaration", line: 1, column: 1),
            ],
            macros: agentGoalMacros
        )
    }

    func testAgentGoalWarnsOnMissingAgenticKeywords() throws {
        assertMacroExpansion(
            """
            @AgentGoal
            static let goal = "Hello world"
            """,
            expandedSource: """
            static let goal = "Hello world"

            static let goal_metadata: AgentGoalMetadata = AgentGoalMetadata(
                maxTurns: 20,
                temperature: 0.7,
                requiresTools: false,
                preferredFormat: .text,
                validatedPrompt: "Hello world"
            )
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "Goal may not encourage agentic behavior — consider adding 'think step-by-step' or 'use tools'",
                    line: 2,
                    column: 19,
                    severity: .warning
                ),
            ],
            macros: agentGoalMacros
        )
    }

    func testAgentGoalDiagnosesInvalidMaxTurns() throws {
        assertMacroExpansion(
            """
            @AgentGoal(maxTurns: 0)
            static let goal = "Think step-by-step."
            """,
            expandedSource: """
            static let goal = "Think step-by-step."
            """,
            diagnostics: [
                DiagnosticSpec(message: "maxTurns must be at least 1", line: 1, column: 1),
            ],
            macros: agentGoalMacros
        )
    }

    func testAgentGoalDiagnosesInvalidTemperature() throws {
        assertMacroExpansion(
            """
            @AgentGoal(temperature: 3.0)
            static let goal = "Think step-by-step."
            """,
            expandedSource: """
            static let goal = "Think step-by-step."
            """,
            diagnostics: [
                DiagnosticSpec(message: "temperature must be between 0 and 2", line: 1, column: 1),
            ],
            macros: agentGoalMacros
        )
    }

    #else
    func testMacrosNotAvailable() throws {
        XCTFail("SwiftSynapseMacros module not available — cannot run macro expansion tests")
    }
    #endif
}
