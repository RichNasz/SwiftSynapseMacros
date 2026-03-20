// Generated strictly from CodeGenSpecs/Client-Types.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import SwiftLLMToolMacros

public enum TextFormat: Sendable {
    case jsonSchema(name: String, schema: JSONSchemaValue, strict: Bool)
    case text
}
