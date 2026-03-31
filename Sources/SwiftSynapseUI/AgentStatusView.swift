// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import SwiftSynapseMacrosClient

/// Displays the current `AgentStatus` as an icon + label.
///
/// - `.idle` — gray circle
/// - `.running` — animated spinner
/// - `.completed` — green checkmark
/// - `.error` — red exclamation with tappable detail
public struct AgentStatusView: View {
    public let status: AgentStatus

    @State private var showingError = false

    public init(status: AgentStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 6) {
            statusIcon
            statusLabel
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundStyle(.yellow)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Button {
                showingError = true
            } label: {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingError) {
                errorDetail
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .idle:
            Text("Idle")
                .foregroundStyle(.secondary)
        case .running:
            Text("Running")
                .foregroundStyle(.primary)
        case .paused:
            Text("Paused")
                .foregroundStyle(.yellow)
        case .completed(let result):
            Text("Completed")
                .foregroundStyle(.green)
                .help(result)
        case .error(let error):
            Text("Error")
                .foregroundStyle(.red)
                .help(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var errorDetail: some View {
        if case .error(let error) = status {
            VStack(alignment: .leading, spacing: 8) {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(error.localizedDescription)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding()
            .frame(minWidth: 200, maxWidth: 400)
        }
    }
}
