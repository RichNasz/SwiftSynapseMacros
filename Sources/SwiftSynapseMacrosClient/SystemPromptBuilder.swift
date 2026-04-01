// Generated from CodeGenSpecs/Client-ProductionPolish.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - System Prompt Section

/// A composable section of a system prompt.
///
/// System prompts are built from multiple sections, each with a priority
/// for ordering and an optional cacheability flag for prompt-caching backends.
public struct SystemPromptSection: Sendable {
    /// Unique identifier for this section (for deduplication and debugging).
    public let id: String
    /// The content of this section.
    public let content: String
    /// Ordering priority (higher = later in the prompt). Default: 100.
    public let priority: Int
    /// Whether this section's content is stable enough to cache.
    public let cacheable: Bool

    public init(
        id: String,
        content: String,
        priority: Int = 100,
        cacheable: Bool = true
    ) {
        self.id = id
        self.content = content
        self.priority = priority
        self.cacheable = cacheable
    }
}

// MARK: - System Prompt Provider

/// Protocol for types that contribute sections to the system prompt.
///
/// Tools, plugins, or other components can conform to this protocol
/// to co-locate their prompt instructions with their implementation.
///
/// ```swift
/// struct CalculateTool: AgentToolProtocol, SystemPromptProvider {
///     func systemPromptSections() -> [SystemPromptSection] {
///         [SystemPromptSection(
///             id: "calculate-instructions",
///             content: "When using the calculate tool, format expressions...",
///             priority: 200
///         )]
///     }
/// }
/// ```
public protocol SystemPromptProvider: Sendable {
    func systemPromptSections() -> [SystemPromptSection]
}

// MARK: - System Prompt Builder

/// Builds system prompts from composable, prioritized sections.
///
/// Sections are collected from static content, dynamic resolvers, and
/// `SystemPromptProvider` conformances, then concatenated in priority order.
///
/// ```swift
/// let builder = SystemPromptBuilder()
/// await builder.addSection(SystemPromptSection(
///     id: "role",
///     content: "You are a helpful customer support agent.",
///     priority: 0
/// ))
/// await builder.addSection(SystemPromptSection(
///     id: "guidelines",
///     content: "Always be polite and professional.",
///     priority: 50
/// ))
/// await builder.addDynamicSection(id: "context", priority: 150) {
///     "Current time: \(Date())"
/// }
///
/// let systemPrompt = try await builder.build()
/// ```
public actor SystemPromptBuilder {
    private var staticSections: [SystemPromptSection] = []
    private var dynamicSections: [(id: String, priority: Int, cacheable: Bool, resolver: @Sendable () async throws -> String)] = []

    public init() {}

    /// Adds a static section to the prompt.
    public func addSection(_ section: SystemPromptSection) {
        // Remove existing section with same id (for updates)
        staticSections.removeAll { $0.id == section.id }
        staticSections.append(section)
    }

    /// Adds a dynamic section that resolves its content at build time.
    ///
    /// Dynamic sections are always marked non-cacheable by default since
    /// their content changes between builds.
    public func addDynamicSection(
        id: String,
        priority: Int = 100,
        cacheable: Bool = false,
        resolver: @escaping @Sendable () async throws -> String
    ) {
        // Remove existing dynamic section with same id
        dynamicSections.removeAll { $0.id == id }
        dynamicSections.append((id: id, priority: priority, cacheable: cacheable, resolver: resolver))
    }

    /// Adds sections from a `SystemPromptProvider`.
    public func addProvider(_ provider: any SystemPromptProvider) {
        for section in provider.systemPromptSections() {
            addSection(section)
        }
    }

    /// Removes a section by its id.
    public func removeSection(id: String) {
        staticSections.removeAll { $0.id == id }
        dynamicSections.removeAll { $0.id == id }
    }

    /// Builds the complete system prompt by resolving all sections and
    /// concatenating them in priority order.
    public func build() async throws -> String {
        var allSections: [(id: String, content: String, priority: Int, cacheable: Bool)] = []

        // Collect static sections
        for section in staticSections {
            allSections.append((section.id, section.content, section.priority, section.cacheable))
        }

        // Resolve dynamic sections
        for dynamic in dynamicSections {
            let content = try await dynamic.resolver()
            allSections.append((dynamic.id, content, dynamic.priority, dynamic.cacheable))
        }

        // Sort by priority (stable sort preserves insertion order for same priority)
        allSections.sort { $0.priority < $1.priority }

        // Concatenate with double newlines
        return allSections
            .map(\.content)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Builds the system prompt preserving cache boundaries.
    ///
    /// Returns sections grouped by cacheability for backends that support
    /// prompt caching (e.g., Anthropic's prompt caching).
    public func buildWithCacheBoundaries() async throws -> [(content: String, cacheable: Bool)] {
        var allSections: [(id: String, content: String, priority: Int, cacheable: Bool)] = []

        for section in staticSections {
            allSections.append((section.id, section.content, section.priority, section.cacheable))
        }
        for dynamic in dynamicSections {
            let content = try await dynamic.resolver()
            allSections.append((dynamic.id, content, dynamic.priority, dynamic.cacheable))
        }

        allSections.sort { $0.priority < $1.priority }

        // Group consecutive sections with the same cacheability
        var result: [(content: String, cacheable: Bool)] = []
        var currentContent = ""
        var currentCacheable = true

        for section in allSections where !section.content.isEmpty {
            if result.isEmpty && currentContent.isEmpty {
                currentContent = section.content
                currentCacheable = section.cacheable
            } else if section.cacheable == currentCacheable {
                currentContent += "\n\n" + section.content
            } else {
                result.append((content: currentContent, cacheable: currentCacheable))
                currentContent = section.content
                currentCacheable = section.cacheable
            }
        }
        if !currentContent.isEmpty {
            result.append((content: currentContent, cacheable: currentCacheable))
        }

        return result
    }

    /// Removes all sections.
    public func clear() {
        staticSections.removeAll()
        dynamicSections.removeAll()
    }
}
