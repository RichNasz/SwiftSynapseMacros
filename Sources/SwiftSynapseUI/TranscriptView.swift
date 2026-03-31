// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import SwiftSynapseMacrosClient

/// Renders an `ObservableTranscript` as a chat-style list.
///
/// - User messages are right-aligned with a blue bubble
/// - Assistant messages are left-aligned with a gray bubble
/// - Tool calls appear as collapsible detail rows
/// - Errors show in red
/// - Streaming text appears at the bottom with a cursor animation
public struct TranscriptView: View {
    @Bindable public var transcript: ObservableTranscript

    public init(transcript: ObservableTranscript) {
        self.transcript = transcript
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(transcript.entries.enumerated()), id: \.offset) { index, entry in
                        entryView(for: entry)
                            .id(index)
                    }

                    if transcript.isStreaming {
                        streamingBubble
                            .id("streaming")
                    }
                }
                .padding()
            }
            .onChange(of: transcript.entries.count) { _, _ in
                withAnimation {
                    if transcript.isStreaming {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    } else if !transcript.entries.isEmpty {
                        proxy.scrollTo(transcript.entries.count - 1, anchor: .bottom)
                    }
                }
            }
            .onChange(of: transcript.streamingText) { _, _ in
                if transcript.isStreaming {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func entryView(for entry: TranscriptEntry) -> some View {
        switch entry {
        case .userMessage(let text):
            userBubble(text)
        case .assistantMessage(let text):
            assistantBubble(text)
        case .reasoning(let item):
            reasoningRow(item)
        case .toolCall(let name, let arguments):
            ToolCallDetailView(name: name, arguments: arguments)
        case .toolResult(let name, let result, let duration):
            ToolCallDetailView(name: name, arguments: "", result: result, duration: duration)
        case .error(let message):
            errorRow(message)
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)
        }
    }

    private func assistantBubble(_ text: String) -> some View {
        HStack {
            Text(text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)
            Spacer(minLength: 60)
        }
    }

    private var streamingBubble: some View {
        HStack {
            StreamingTextView(transcript: transcript)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 60)
        }
    }

    private func reasoningRow(_ item: ReasoningItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "brain")
                .foregroundStyle(.purple)
            if let summaries = item.summary {
                Text(summaries.map(\.text).joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text("Reasoning...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
        .padding(8)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
