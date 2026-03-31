// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import SwiftSynapseMacrosClient

/// A complete drop-in chat UI for any `ObservableAgent`.
///
/// Combines a text input, send button, transcript view, and status indicator.
/// Bind to any agent conforming to `ObservableAgent` for a full chat experience.
public struct AgentChatView<A: ObservableAgent>: View {
    public let agent: A

    @State private var inputText = ""
    @State private var isRunning = false
    @State private var currentStatus: AgentStatus = .idle
    @State private var currentTranscript: ObservableTranscript?

    public init(agent: A) {
        self.agent = agent
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                AgentStatusView(status: currentStatus)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Transcript
            if let transcript = currentTranscript {
                TranscriptView(transcript: transcript)
            } else {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Enter a goal to start the agent.")
                )
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                TextField("Enter a goal...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendGoal()
                    }
                    .disabled(isRunning)

                Button {
                    sendGoal()
                } label: {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
    }

    private func sendGoal() {
        let goal = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty, !isRunning else { return }

        inputText = ""
        isRunning = true

        Task {
            currentTranscript = await agent.transcript
            do {
                _ = try await agent.execute(goal: goal)
            } catch {
                // Error is reflected in agent.status
            }
            currentStatus = await agent.status
            isRunning = false
        }
    }
}
