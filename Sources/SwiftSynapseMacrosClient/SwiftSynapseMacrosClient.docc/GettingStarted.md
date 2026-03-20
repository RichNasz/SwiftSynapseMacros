# Getting Started

Learn how to add SwiftSynapseMacros to your project and create your first agent.

## Overview

SwiftSynapseMacros lets you create LLM-powered agents with minimal boilerplate. This guide walks you through installation, creating an agent actor, injecting an LLM client, and running your first conversation.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Installation

Add SwiftSynapseMacros to your `Package.swift`:

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
            ]
        ),
    ]
)
```

Importing `SwiftSynapseMacrosClient` also gives you access to SwiftOpenResponsesDSL and SwiftLLMToolMacros types via re-exports.

## Create an Agent

Annotate an `actor` with `@SpecDrivenAgent` to generate the full agent scaffold:

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
actor ResearchAgent {
    // The macro generates:
    // - Status enum (idle, running, completed, failed)
    // - _status, _transcript, _dslAgent stored properties
    // - status, isRunning, transcript computed properties
    // - client: LLMClient? stored property
    // - run(_:) async throws -> String method
}
```

## Inject an LLM Client

Before calling `run(_:)`, set the agent's `client` property with an `LLMClient` from SwiftOpenResponsesDSL:

```swift
let agent = ResearchAgent()

let client = try LLMClient(
    baseURLString: "https://api.openai.com/v1/responses",
    apiKey: apiKey
)

agent.client = client
```

## Run a Conversation

Call `run(_:)` with a user message. The method manages status transitions, calls the LLM, and appends entries to the transcript:

```swift
do {
    let response = try await agent.run("What is quantum computing?")
    print(response)

    // Check agent state
    print(agent.status)       // .completed
    print(agent.transcript)   // [user entry, assistant entry]
} catch {
    print(agent.status)       // .failed
}
```

## Observe in SwiftUI

Use `ObservableTranscript` to bind agent conversation state to your UI:

```swift
let observable = ObservableTranscript()

// Sync from agent transcript
observable.sync(from: agent.transcript)

// Use in SwiftUI views
struct ChatView: View {
    @State var transcript = ObservableTranscript()

    var body: some View {
        List(transcript.entries, id: \.content) { entry in
            Text("\(entry.role): \(entry.content)")
        }
    }
}
```

## Next Steps

- Read the <doc:MacroReference> for details on all three macros
- See the <doc:IntegrationGuide> to understand how the packages work together
