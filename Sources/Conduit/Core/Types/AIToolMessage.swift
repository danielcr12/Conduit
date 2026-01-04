// AIToolMessage.swift
// Conduit

import Foundation
import Logging

// MARK: - AIToolCall

/// A tool call made by the LLM.
///
/// Represents a request from the language model to invoke a specific tool
/// with the provided arguments. Tool calls are typically extracted from
/// the model's response and executed by the application.
///
/// ## Usage
///
/// ```swift
/// // Received from LLM response
/// let toolCall = try AIToolCall(
///     id: "call_abc123",
///     toolName: "get_weather",
///     arguments: StructuredContent(json: "{\"city\": \"Paris\"}")
/// )
///
/// // Execute the tool
/// if let tool = tools.first(where: { $0.name == toolCall.toolName }) {
///     let result = try await tool.call(try toolCall.argumentsData())
/// }
/// ```
///
/// ## Parallel Tool Calls
///
/// Some models can request multiple tool calls in a single response.
/// Each call has a unique `id` to correlate with its result:
///
/// ```swift
/// let calls: [AIToolCall] = response.toolCalls
/// let results = try await withThrowingTaskGroup(of: AIToolOutput.self) { group in
///     for call in calls {
///         group.addTask {
///             let result = try await executeToolCall(call)
///             return AIToolOutput(id: call.id, toolName: call.toolName, content: result)
///         }
///     }
///     return try await group.reduce(into: []) { $0.append($1) }
/// }
/// ```
///
/// ## Thread Safety
///
/// `AIToolCall` is `Sendable` and can be safely passed across actor boundaries.
public struct AIToolCall: Sendable, Equatable, Identifiable, Hashable {

    // MARK: - Properties

    /// A unique identifier for this tool call.
    ///
    /// This ID is provided by the LLM and must be included in the
    /// corresponding `AIToolOutput` to correlate the result.
    ///
    /// The format varies by provider (e.g., OpenAI uses `call_xxx`).
    public let id: String

    /// The name of the tool to invoke.
    ///
    /// This should match the `name` property of a registered `AITool`.
    public let toolName: String

    /// The arguments for the tool call as structured content.
    ///
    /// Contains the parsed JSON arguments from the LLM response.
    /// Use `argumentsData()` to get the raw JSON data for tool execution.
    public let arguments: StructuredContent

    // MARK: - Initialization

    /// Creates a new tool call with validation.
    ///
    /// Tool names must be non-empty and contain only alphanumeric characters,
    /// underscores, and hyphens.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for this call (from the LLM).
    ///   - toolName: The name of the tool to invoke.
    ///   - arguments: The structured arguments for the tool.
    /// - Throws: `AIError.invalidToolName` if the tool name is invalid.
    public init(id: String, toolName: String, arguments: StructuredContent) throws {
        try Self.validateToolName(toolName)
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
    }

    /// Creates a new tool call from JSON string arguments with validation.
    ///
    /// Tool names must be non-empty and contain only alphanumeric characters,
    /// underscores, and hyphens.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for this call.
    ///   - toolName: The name of the tool to invoke.
    ///   - argumentsJSON: The JSON string containing the arguments.
    /// - Throws: `AIError.invalidToolName` if the tool name is invalid.
    /// - Throws: `StructuredContentError.invalidJSON` if the JSON string cannot be parsed.
    public init(id: String, toolName: String, argumentsJSON: String) throws {
        try Self.validateToolName(toolName)
        self.id = id
        self.toolName = toolName
        self.arguments = try StructuredContent(json: argumentsJSON)
    }

    // MARK: - Validation

    /// Regex pattern for valid tool names.
    /// Valid tool names contain only alphanumeric characters, underscores, and hyphens.
    /// Using Swift regex literal for compile-time validation (no runtime failure risk).
    /// Marked `nonisolated(unsafe)` because Regex literals are immutable and thread-safe.
    nonisolated(unsafe) private static let validToolNameRegex = /^[a-zA-Z0-9_-]+$/

    /// Validates a tool name.
    ///
    /// - Parameter name: The tool name to validate.
    /// - Throws: `AIError.invalidToolName` if the name is invalid.
    private static func validateToolName(_ name: String) throws {
        if name.isEmpty {
            ConduitLoggers.tools.warning("Invalid tool name: empty string")
            throw AIError.invalidToolName(name: name, reason: "Tool name cannot be empty")
        }

        guard name.wholeMatch(of: validToolNameRegex) != nil else {
            ConduitLoggers.tools.warning(
                "Invalid tool name",
                metadata: [
                    "toolName": .string(name),
                    "reason": .string("Contains invalid characters")
                ]
            )
            throw AIError.invalidToolName(
                name: name,
                reason: "Tool name must contain only alphanumeric characters, underscores, and hyphens"
            )
        }
    }

    // MARK: - Methods

    /// Returns the arguments serialized as JSON Data.
    ///
    /// Use this method to pass arguments to `AITool.call(_:)`.
    ///
    /// - Returns: JSON-encoded Data of the arguments
    /// - Throws: If serialization fails
    public func argumentsData() throws -> Data {
        try arguments.toData()
    }

    /// The arguments as a JSON string.
    ///
    /// Useful for logging or debugging tool calls.
    ///
    /// - Returns: The JSON string representation of the arguments, or "{}" if serialization fails.
    public var argumentsString: String {
        (try? arguments.toJSON()) ?? "{}"
    }
}

// MARK: - AIToolOutput

/// The output from a tool execution.
///
/// Represents the result of executing a tool call, which is sent back
/// to the LLM to continue the conversation. The `id` must match the
/// original `AIToolCall.id` to properly correlate the result.
///
/// ## Usage
///
/// ```swift
/// let toolCall = response.toolCalls.first!
/// let result = try await weatherTool.call(try toolCall.argumentsData())
///
/// let output = AIToolOutput(
///     id: toolCall.id,
///     toolName: toolCall.toolName,
///     content: result.text
/// )
///
/// // Include in the next request
/// let message = Message.toolOutput(output)
/// ```
///
/// ## Error Handling
///
/// When a tool fails, you can return an error message as the content:
///
/// ```swift
/// let output: AIToolOutput
/// do {
///     let result = try await tool.call(try toolCall.argumentsData())
///     output = AIToolOutput(
///         id: toolCall.id,
///         toolName: toolCall.toolName,
///         content: result.text
///     )
/// } catch {
///     output = AIToolOutput(
///         id: toolCall.id,
///         toolName: toolCall.toolName,
///         content: "Error: \(error.localizedDescription)"
///     )
/// }
/// ```
///
/// ## Thread Safety
///
/// `AIToolOutput` is `Sendable` and can be safely passed across actor boundaries.
public struct AIToolOutput: Sendable, Equatable, Hashable {

    // MARK: - Properties

    /// The ID of the tool call this output corresponds to.
    ///
    /// Must match the `id` from the original `AIToolCall`.
    public let id: String

    /// The name of the tool that produced this output.
    ///
    /// Should match the `toolName` from the original `AIToolCall`.
    public let toolName: String

    /// The textual content of the tool's output.
    ///
    /// This is the result that will be included in the conversation
    /// for the LLM to process.
    public let content: String

    // MARK: - Initialization

    /// Creates a new tool output.
    ///
    /// - Parameters:
    ///   - id: The ID of the corresponding tool call.
    ///   - toolName: The name of the tool that produced this output.
    ///   - content: The textual content of the result.
    public init(id: String, toolName: String, content: String) {
        self.id = id
        self.toolName = toolName
        self.content = content
    }

    /// Creates a tool output from a tool call and result.
    ///
    /// Convenience initializer that extracts the `id` and `toolName`
    /// from the original tool call.
    ///
    /// - Parameters:
    ///   - call: The original tool call.
    ///   - content: The textual content of the result.
    public init(call: AIToolCall, content: String) {
        self.id = call.id
        self.toolName = call.toolName
        self.content = content
    }

    /// Creates a tool output from a tool call and a PromptRepresentable result.
    ///
    /// Convenience initializer that extracts text from the result.
    ///
    /// - Parameters:
    ///   - call: The original tool call.
    ///   - result: The result conforming to PromptRepresentable.
    public init(call: AIToolCall, result: any PromptRepresentable) {
        self.id = call.id
        self.toolName = call.toolName
        self.content = result.text
    }
}

// MARK: - Message Extension

extension Message {

    /// Creates a tool output message.
    ///
    /// Use this factory method to create a message containing the result
    /// of a tool execution. The message will have the `.tool` role.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let output = AIToolOutput(
    ///     id: "call_abc123",
    ///     toolName: "get_weather",
    ///     content: "Temperature in Paris: 22C, Sunny"
    /// )
    ///
    /// let message = Message.toolOutput(output)
    /// messages.append(message)
    /// ```
    ///
    /// ## Multiple Tool Results
    ///
    /// When handling parallel tool calls, create a message for each result:
    ///
    /// ```swift
    /// for output in toolOutputs {
    ///     messages.append(Message.toolOutput(output))
    /// }
    /// ```
    ///
    /// - Parameter output: The tool output to include in the message.
    /// - Returns: A message with `role: .tool` containing the tool result.
    public static func toolOutput(_ output: AIToolOutput) -> Message {
        Message(
            role: .tool,
            content: .text(output.content),
            metadata: MessageMetadata(
                custom: [
                    "tool_call_id": output.id,
                    "tool_name": output.toolName
                ]
            )
        )
    }

    /// Creates a tool output message from a tool call and result.
    ///
    /// Convenience method that creates the `AIToolOutput` internally.
    ///
    /// - Parameters:
    ///   - call: The tool call that was executed.
    ///   - content: The textual content of the result.
    /// - Returns: A message with `role: .tool` containing the tool result.
    public static func toolOutput(call: AIToolCall, content: String) -> Message {
        toolOutput(AIToolOutput(call: call, content: content))
    }

    /// Creates a tool output message from a tool call and PromptRepresentable result.
    ///
    /// Convenience method for returning structured results.
    ///
    /// - Parameters:
    ///   - call: The tool call that was executed.
    ///   - result: The result conforming to PromptRepresentable.
    /// - Returns: A message with `role: .tool` containing the tool result.
    public static func toolOutput(call: AIToolCall, result: any PromptRepresentable) -> Message {
        toolOutput(AIToolOutput(call: call, result: result))
    }
}

// MARK: - AIToolCall Collection Extension

extension Collection where Element == AIToolCall {

    /// Finds a tool call by name.
    ///
    /// - Parameter name: The tool name to search for.
    /// - Returns: The first tool call with the matching name, or `nil`.
    public func call(named name: String) -> AIToolCall? {
        first { $0.toolName == name }
    }

    /// Filters tool calls by name.
    ///
    /// - Parameter name: The tool name to filter by.
    /// - Returns: All tool calls with the matching name.
    public func calls(named name: String) -> [AIToolCall] {
        filter { $0.toolName == name }
    }
}

// MARK: - Codable Conformance

extension AIToolCall: Codable {

    private enum CodingKeys: String, CodingKey {
        case id
        case toolName = "tool_name"
        case arguments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)

        let decodedToolName = try container.decode(String.self, forKey: .toolName)
        try Self.validateToolName(decodedToolName)
        self.toolName = decodedToolName

        // Arguments can be either a string (JSON) or an object
        if let jsonString = try? container.decode(String.self, forKey: .arguments) {
            self.arguments = try StructuredContent(json: jsonString)
        } else {
            // Decode as StructuredContent directly
            let argumentsDict = try container.decode([String: AnyCodable].self, forKey: .arguments)
            let jsonData = try JSONEncoder().encode(argumentsDict)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            self.arguments = try StructuredContent(json: jsonString)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(toolName, forKey: .toolName)
        try container.encode(arguments.toJSON(), forKey: .arguments)
    }
}

extension AIToolOutput: Codable {

    private enum CodingKeys: String, CodingKey {
        case id = "tool_call_id"
        case toolName = "tool_name"
        case content
    }
}

