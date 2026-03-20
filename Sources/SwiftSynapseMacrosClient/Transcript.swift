// Generated strictly from CodeGenSpecs/Client-Types.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import Observation

@Observable
public final class ObservableTranscript {
    public private(set) var entries: [TranscriptEntry] = []
    public private(set) var isStreaming: Bool = false
    public private(set) var streamingText: String = ""

    public init() {}

    public func sync(from transcript: [TranscriptEntry]) {
        entries = transcript
    }

    public func append(_ entry: TranscriptEntry) {
        entries.append(entry)
    }

    public func setStreaming(_ streaming: Bool) {
        isStreaming = streaming
        if !streaming {
            streamingText = ""
        }
    }

    public func appendDelta(_ text: String) {
        streamingText += text
    }

    public func reset() {
        entries = []
        isStreaming = false
        streamingText = ""
    }
}
