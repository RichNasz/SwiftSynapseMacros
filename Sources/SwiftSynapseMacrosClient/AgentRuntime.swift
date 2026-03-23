// Generated from CodeGenSpecs/Client-Types.md — Do not edit manually. Update spec and re-generate.

public enum AgentRuntime {
    public static func execute(
        goal: String,
        transcript: ObservableTranscript,
        client: LLMClient,
        maxTurns: Int = 20
    ) async throws -> Any {
        transcript.reset()
        transcript.append(.userMessage(goal))

        // TODO: Implement dynamic runtime reasoning loop
        // 1. Build prompt from transcript + tool descriptions
        // 2. Call client.send(request) in a loop
        // 3. Parse tool calls vs final answer
        // 4. Execute tools, append results, continue loop
        // 5. Return final result on completion or max turns

        let request = try ResponseRequest(model: "gpt-4o", text: goal)
        let response = try await client.send(request)
        let text = response.firstOutputText ?? ""
        transcript.append(.assistantMessage(text))
        return text as Any
    }
}
