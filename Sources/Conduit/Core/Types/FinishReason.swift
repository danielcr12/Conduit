// FinishReason.swift
// Conduit

import Foundation

/// Reason why generation stopped.
///
/// Every generation operation terminates for a specific reason,
/// whether natural completion, hitting limits, or external factors.
///
/// ## Usage
/// ```swift
/// switch result.finishReason {
/// case .stop:
///     print("Completed naturally")
/// case .maxTokens:
///     print("Hit token limit")
/// case .cancelled:
///     print("User cancelled")
/// default:
///     break
/// }
/// ```
///
/// ## Tool Calling
///
/// When the model wants to invoke tools, generation stops with either:
/// - ``toolCall``: Used by Anthropic and some providers (singular form)
/// - ``toolCalls``: Used by OpenAI (plural form, even for single calls)
///
/// Use ``isToolCallRequest`` to check for either case:
/// ```swift
/// if result.finishReason?.isToolCallRequest == true {
///     // Execute tool calls from the response
///     for call in result.toolCalls ?? [] {
///         let result = try await executor.execute(call)
///     }
/// }
/// ```
public enum FinishReason: String, Sendable, Codable, Hashable {
    /// Natural end of generation (EOS token).
    case stop

    /// Reached maximum token limit.
    case maxTokens = "max_tokens"

    /// Hit a stop sequence.
    case stopSequence = "stop_sequence"

    /// User cancelled generation.
    case cancelled

    /// Content filtered by safety systems.
    case contentFilter = "content_filter"

    /// Tool call requested (singular form).
    ///
    /// Used by Anthropic and some providers when the model wants to invoke tools.
    /// Check ``isToolCallRequest`` for a provider-agnostic way to detect tool calls.
    ///
    /// - SeeAlso: ``toolCalls`` for the plural form used by OpenAI.
    case toolCall = "tool_call"

    /// Tool calls requested (plural form).
    ///
    /// Used by OpenAI when the model wants to invoke tools.
    /// This is returned even when only a single tool is called.
    /// Check ``isToolCallRequest`` for a provider-agnostic way to detect tool calls.
    ///
    /// - SeeAlso: ``toolCall`` for the singular form used by Anthropic.
    case toolCalls = "tool_calls"

    /// Generation paused for long-running turns (can be resumed).
    case pauseTurn = "pause_turn"

    /// Model reached its context window limit.
    case modelContextWindowExceeded = "model_context_window_exceeded"

    // MARK: - Computed Properties

    /// Returns true if this finish reason indicates the model wants to call tools.
    ///
    /// This is a provider-agnostic way to check for tool call requests,
    /// handling both ``toolCall`` (Anthropic) and ``toolCalls`` (OpenAI) cases.
    ///
    /// ## Usage
    /// ```swift
    /// if result.finishReason?.isToolCallRequest == true {
    ///     for call in result.toolCalls ?? [] {
    ///         let result = try await executor.execute(call)
    ///     }
    /// }
    /// ```
    public var isToolCallRequest: Bool {
        self == .toolCall || self == .toolCalls
    }
}
