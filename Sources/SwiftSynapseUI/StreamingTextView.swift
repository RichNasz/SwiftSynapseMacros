// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import SwiftSynapseMacrosClient

/// Renders streaming text with a typing cursor animation.
///
/// Observes `ObservableTranscript.streamingText` and shows a blinking cursor
/// while `isStreaming` is true. Transitions to final text when streaming ends.
public struct StreamingTextView: View {
    @Bindable public var transcript: ObservableTranscript

    @State private var cursorVisible = true

    public init(transcript: ObservableTranscript) {
        self.transcript = transcript
    }

    public var body: some View {
        if transcript.isStreaming {
            HStack(alignment: .bottom, spacing: 0) {
                Text(transcript.streamingText)
                    .textSelection(.enabled)
                if cursorVisible {
                    Text("|")
                        .foregroundStyle(.primary)
                        .opacity(0.6)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    cursorVisible.toggle()
                }
            }
        } else if !transcript.streamingText.isEmpty {
            Text(transcript.streamingText)
                .textSelection(.enabled)
        }
    }
}
