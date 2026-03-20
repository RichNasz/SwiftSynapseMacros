// Generated from CodeGenSpecs/Client-Types.md — Do not edit manually. Update spec and re-generate.
import SwiftLLMToolMacros

public enum TextFormat: Sendable {
    case jsonSchema(name: String, schema: JSONSchemaValue, strict: Bool)
    case text
}
