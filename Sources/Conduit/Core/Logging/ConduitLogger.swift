// ConduitLogger.swift
// Conduit
//
// Cross-platform logging using swift-log.

import Foundation
import Logging

// MARK: - Conduit Loggers

/// Pre-configured loggers for different Conduit subsystems.
///
/// Uses swift-log for cross-platform compatibility (macOS, iOS, Linux).
///
/// ## Usage
/// ```swift
/// ConduitLoggers.openAI.warning("Rate limit approaching")
/// ConduitLoggers.anthropic.debug("Request started")
/// ConduitLoggers.streaming.error("Buffer overflow")
/// ```
///
/// ## Configuration
/// By default, logs go to stdout via `StreamLogHandler`. To customize:
/// ```swift
/// LoggingSystem.bootstrap { label in
///     // Your custom log handler
/// }
/// ```
internal enum ConduitLoggers {

    /// Logger for OpenAI provider operations.
    static let openAI = Logger(label: "com.conduit.openai")

    /// Logger for Anthropic provider operations.
    static let anthropic = Logger(label: "com.conduit.anthropic")

    /// Logger for streaming operations.
    static let streaming = Logger(label: "com.conduit.streaming")

    /// Logger for tool calling operations.
    static let tools = Logger(label: "com.conduit.tools")

    /// Logger for model management operations.
    static let modelManager = Logger(label: "com.conduit.model-manager")

    /// Logger for general Conduit operations.
    static let general = Logger(label: "com.conduit")
}
