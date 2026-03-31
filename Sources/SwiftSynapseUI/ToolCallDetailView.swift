// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import SwiftSynapseMacrosClient

/// An expandable row showing tool call details: name, arguments (JSON), result, and duration.
public struct ToolCallDetailView: View {
    public let name: String
    public let arguments: String
    public let result: String?
    public let duration: Duration?

    @State private var isExpanded = false

    public init(name: String, arguments: String, result: String? = nil, duration: Duration? = nil) {
        self.name = name
        self.arguments = arguments
        self.result = result
        self.duration = duration
    }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Section {
                    Text(formatJSON(arguments))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } header: {
                    Text("Arguments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let result {
                    Section {
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } header: {
                        Text("Result")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.orange)
                Text(name)
                    .fontWeight(.medium)
                Spacer()
                if let duration {
                    Text(duration, format: .units(allowed: [.seconds, .milliseconds], width: .abbreviated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func formatJSON(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let formatted = String(data: pretty, encoding: .utf8) else {
            return raw
        }
        return formatted
    }
}
