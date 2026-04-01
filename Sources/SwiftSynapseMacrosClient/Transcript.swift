// Generated strictly from CodeGenSpecs/Client-Types.md + Overview.md
// Do not edit manually — update the corresponding spec file and re-generate
import Observation

@Observable
public final class ObservableTranscript: @unchecked Sendable {
    public private(set) var entries: [TranscriptEntry] = []
    public private(set) var isStreaming: Bool = false
    public private(set) var streamingText: String = ""
    /// Active tool progress updates, keyed by callId.
    public private(set) var toolProgress: [String: ToolProgressUpdate] = [:]

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

    /// Updates tool progress for a given call ID.
    public func updateToolProgress(_ update: ToolProgressUpdate) {
        toolProgress[update.callId] = update
    }

    /// Clears tool progress for a completed call.
    public func clearToolProgress(callId: String) {
        toolProgress.removeValue(forKey: callId)
    }

    public func reset() {
        entries = []
        isStreaming = false
        streamingText = ""
        toolProgress = [:]
    }

    /// Restores transcript state from a saved session.
    public func restore(entries: [TranscriptEntry]) {
        self.entries = entries
        self.isStreaming = false
        self.streamingText = ""
    }

    /// Restores transcript state from codable entries.
    public func restore(from codableEntries: [CodableTranscriptEntry]) {
        self.entries = codableEntries.map { $0.toTranscriptEntry() }
        self.isStreaming = false
        self.streamingText = ""
    }
}
