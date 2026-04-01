// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

/// Manages an ordered list of hooks and fires events through them.
///
/// Hooks are evaluated in registration order. If any hook returns `.block`,
/// the pipeline short-circuits and returns that action immediately.
public actor AgentHookPipeline {
    private var hooks: [any AgentHook] = []

    public init() {}

    /// Registers a hook in the pipeline.
    public func add(_ hook: any AgentHook) {
        hooks.append(hook)
    }

    /// Fires an event through all matching hooks.
    ///
    /// Returns `.block` if any hook blocks; otherwise `.proceed`.
    /// `.modify` actions are passed through (the caller decides how to apply them).
    @discardableResult
    public func fire(_ event: AgentHookEvent) async -> HookAction {
        let kind = event.kind
        for hook in hooks where hook.subscribedEvents.contains(kind) {
            let action = await hook.handle(event)
            switch action {
            case .block:
                return action
            case .modify:
                return action
            case .proceed:
                continue
            }
        }
        return .proceed
    }
}
