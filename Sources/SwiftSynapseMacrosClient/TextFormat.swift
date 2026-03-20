import SwiftLLMToolMacros

public enum TextFormat: Sendable {
    case jsonSchema(name: String, schema: JSONSchemaValue, strict: Bool)
    case text
}
