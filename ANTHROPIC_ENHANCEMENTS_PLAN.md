# Anthropic Provider Enhancement Plan

**Created**: 2025-12-26
**Status**: Planning Phase
**Target**: SwiftAI Framework - Anthropic Provider Completeness

---

## Executive Summary

This document provides a comprehensive implementation plan for addressing all gaps identified in the SwiftAI Anthropic provider through:
- Official Anthropic API Documentation Analysis (https://platform.claude.com/docs/en/api/messages)
- SwiftAnthropic SDK Comparison (https://github.com/jamesrochabrun/SwiftAnthropic)
- SwiftClaude SDK Comparison (https://github.com/GeorgeLyon/SwiftClaude)
- Code Review Findings

**Total Gaps Identified**: 20 issues across 4 severity levels
**Estimated Total Effort**: 6-8 weeks (phased implementation)

---

## Phase Overview

| Phase | Focus | Issues | Effort | Priority |
|-------|-------|--------|--------|----------|
| Phase 12 | Critical Fixes | 7 issues | 1-2 weeks | CRITICAL |
| Phase 13 | Tool Use | 1 major feature | 2-3 weeks | HIGH |
| Phase 14 | Prompt Caching | 1 major feature | 1 week | HIGH |
| Phase 15 | PDF/Documents | 1 major feature | 1-2 weeks | MEDIUM |
| Phase 16 | Advanced APIs | 3 features | 2-3 weeks | MEDIUM |
| Phase 17 | Polish | Remaining | 1 week | LOW |

---

# Phase 12: Critical Fixes (IMMEDIATE)

**Objective**: Fix critical bugs and complete core API coverage
**Effort**: 1-2 weeks
**Dependencies**: None - can start immediately

---

## Issue 12.1: Missing Model IDs (CRITICAL)

### Source
- **Anthropic Docs**: https://platform.claude.com/docs/en/about-claude/models/overview
- **Discovery**: Web search results (December 2025)

### Current State
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicModelID.swift`
**Lines**: 20-43

```swift
// Current implementation only has 6 models
extension AnthropicModelID {
    public static let claudeOpus45 = AnthropicModelID("claude-opus-4-5-20251101")
    public static let claudeSonnet45 = AnthropicModelID("claude-sonnet-4-5-20250929")
    public static let claude35Sonnet = AnthropicModelID("claude-3-5-sonnet-20241022")
    public static let claude3Opus = AnthropicModelID("claude-3-opus-20240229")
    public static let claude3Sonnet = AnthropicModelID("claude-3-sonnet-20240229")
    public static let claude3Haiku = AnthropicModelID("claude-3-haiku-20240307")
}
```

### Missing Models (December 2025)
1. `claude-3-7-sonnet-20250219` / `claude-3-7-sonnet-latest` - Extended thinking model
2. `claude-haiku-4-5-20251001` / `claude-haiku-4-5` - Hybrid fast model with thinking
3. `claude-3-5-haiku-20241022` / `claude-3-5-haiku-latest` - Fastest compact model
4. `claude-sonnet-4-20250514` / `claude-4-sonnet-20250514` - High-performance variant
5. `claude-opus-4-20250514` / `claude-4-opus-20250514` / `claude-opus-4-1-20250805` - Most capable

### Proposed Fix

```swift
// File: /Sources/SwiftAI/Providers/Anthropic/AnthropicModelID.swift
// Lines: 20-60
extension AnthropicModelID {
    // MARK: - Claude Opus 4.x Family

    /// Claude Opus 4.5 - Premium model combining maximum intelligence with practical performance.
    /// Released: November 2025
    /// Best for: Complex reasoning, analysis, professional software engineering
    public static let claudeOpus45 = AnthropicModelID("claude-opus-4-5-20251101")

    /// Claude Opus 4 (May 2025) - Alternative Opus 4 snapshot
    public static let claudeOpus4 = AnthropicModelID("claude-opus-4-20250514")

    /// Claude Opus 4.1 (August 2025) - Enhanced Opus variant
    public static let claudeOpus41 = AnthropicModelID("claude-opus-4-1-20250805")

    // MARK: - Claude Sonnet 4.x Family

    /// Claude Sonnet 4.5 - Best model for real-world agents and coding.
    /// Released: September 2025
    /// Best for: Balanced performance, production agents, coding
    public static let claudeSonnet45 = AnthropicModelID("claude-sonnet-4-5-20250929")

    /// Claude Sonnet 4 (May 2025) - High-performance with extended thinking
    public static let claudeSonnet4 = AnthropicModelID("claude-sonnet-4-20250514")

    // MARK: - Claude 3.x Sonnet Family

    /// Claude 3.7 Sonnet - High-performance with early extended thinking support.
    /// Released: February 2025
    /// Best for: Complex tasks requiring step-by-step reasoning
    public static let claude37Sonnet = AnthropicModelID("claude-3-7-sonnet-20250219")

    /// Claude 3.5 Sonnet - Enhanced reasoning and coding capabilities.
    /// Released: October 2024
    public static let claude35Sonnet = AnthropicModelID("claude-3-5-sonnet-20241022")

    // MARK: - Claude Haiku 4.x Family

    /// Claude Haiku 4.5 - Hybrid model with near-instant responses and extended thinking.
    /// Released: October 2025
    /// Best for: Fast responses with optional deep reasoning
    public static let claudeHaiku45 = AnthropicModelID("claude-haiku-4-5-20251001")

    /// Claude 3.5 Haiku - Fastest and most compact model.
    /// Released: October 2024
    /// Best for: Speed-critical applications, cost optimization
    public static let claude35Haiku = AnthropicModelID("claude-3-5-haiku-20241022")

    // MARK: - Claude 3.x Legacy Models

    /// Claude 3 Opus - Legacy flagship model.
    /// Released: February 2024
    public static let claude3Opus = AnthropicModelID("claude-3-opus-20240229")

    /// Claude 3 Sonnet - Legacy balanced model.
    /// Released: February 2024
    public static let claude3Sonnet = AnthropicModelID("claude-3-sonnet-20240229")

    /// Claude 3 Haiku - Legacy fast model.
    /// Released: March 2024
    public static let claude3Haiku = AnthropicModelID("claude-3-haiku-20240307")
}
```

### Rationale
Official Anthropic documentation shows these models are available as of December 2025. Users need access to the latest models, especially Claude 3.7 Sonnet (extended thinking), Haiku 4.5 (hybrid speed/thinking), and the various Opus/Sonnet 4.x variants.

### Testing
**File**: `/Tests/SwiftAITests/Providers/Anthropic/AnthropicProviderTests.swift`

Add to `AnthropicModelIDTests` suite:
```swift
@Test("All 2025 model IDs are supported")
func test2025Models() {
    #expect(AnthropicModelID.claude37Sonnet.rawValue == "claude-3-7-sonnet-20250219")
    #expect(AnthropicModelID.claudeHaiku45.rawValue == "claude-haiku-4-5-20251001")
    #expect(AnthropicModelID.claude35Haiku.rawValue == "claude-3-5-haiku-20241022")
    #expect(AnthropicModelID.claudeSonnet4.rawValue == "claude-sonnet-4-20250514")
    #expect(AnthropicModelID.claudeOpus4.rawValue == "claude-opus-4-20250514")
    #expect(AnthropicModelID.claudeOpus41.rawValue == "claude-opus-4-1-20250805")
}
```

### Complexity
**Simple** - 30 minutes (copy/paste + documentation)

---

## Issue 12.2: Retry Logic Not Implemented (CRITICAL)

### Source
- **Code Review Finding**: Critical issue #1
- **Anthropic Best Practices**: https://platform.claude.com/docs/en/api/errors

### Current State
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`
**Lines**: 199-252

```swift
// Current code executes request exactly ONCE - no retries
internal func executeRequest(
    _ request: AnthropicMessagesRequest
) async throws -> AnthropicMessagesResponse {
    let url = configuration.baseURL.appendingPathComponent("/v1/messages")
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"

    for (name, value) in configuration.buildHeaders() {
        urlRequest.setValue(value, forHTTPHeaderField: name)
    }

    do {
        urlRequest.httpBody = try encoder.encode(request)
    } catch {
        throw AIError.generationFailed(underlying: SendableError(error))
    }

    // Execute request - SINGLE ATTEMPT, NO RETRY
    let (data, response): (Data, URLResponse)
    do {
        (data, response) = try await session.data(for: urlRequest)
    } catch let urlError as URLError {
        throw AIError.networkError(urlError)
    } catch {
        throw AIError.networkError(URLError(.unknown))
    }

    // ... validation code ...
}
```

**Configuration defines but never uses**:
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicConfiguration.swift`
**Line**: 85-86
```swift
public let maxRetries: Int  // Defined but never used!
```

### Proposed Fix

```swift
// File: /Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift
// Lines: 199-300 (replace entire method)

/// Executes HTTP request to Anthropic Messages API with retry logic.
///
/// Implements exponential backoff retry strategy for:
/// - Network failures (URLError)
/// - Rate limits (429)
/// - Server errors (500-599)
///
/// Non-retryable errors (client errors 400-499 except 429) fail immediately.
///
/// ## Retry Strategy
/// - Attempt 0: Immediate
/// - Attempt 1: Wait 1 second (2^0)
/// - Attempt 2: Wait 2 seconds (2^1)
/// - Attempt 3: Wait 4 seconds (2^2)
/// - Maximum attempts: `configuration.maxRetries + 1`
///
/// - Parameter request: The Anthropic API request to execute.
/// - Returns: The decoded `AnthropicMessagesResponse`.
/// - Throws: `AIError` after all retry attempts exhausted.
internal func executeRequest(
    _ request: AnthropicMessagesRequest
) async throws -> AnthropicMessagesResponse {
    var lastError: Error?

    for attempt in 0...configuration.maxRetries {
        do {
            // Build URLRequest
            let url = configuration.baseURL.appendingPathComponent("/v1/messages")
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"

            // Add headers (authentication, API version, content-type)
            for (name, value) in configuration.buildHeaders() {
                urlRequest.setValue(value, forHTTPHeaderField: name)
            }

            // Encode request body
            do {
                urlRequest.httpBody = try encoder.encode(request)
            } catch {
                // Encoding errors are non-retryable
                throw AIError.generationFailed(underlying: SendableError(error))
            }

            // Execute request
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: urlRequest)
            } catch let urlError as URLError {
                // Network errors are retryable
                if attempt < configuration.maxRetries {
                    lastError = AIError.networkError(urlError)
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue  // Retry
                } else {
                    throw AIError.networkError(urlError)
                }
            } catch {
                if attempt < configuration.maxRetries {
                    lastError = AIError.networkError(URLError(.unknown))
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue  // Retry
                } else {
                    throw AIError.networkError(URLError(.unknown))
                }
            }

            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.networkError(URLError(.badServerResponse))
            }

            // Success case
            if (200...299).contains(httpResponse.statusCode) {
                return try decoder.decode(AnthropicMessagesResponse.self, from: data)
            }

            // Determine if error is retryable
            let isRetryable = httpResponse.statusCode == 429 || httpResponse.statusCode >= 500

            // Try to decode error response
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                let error = mapAnthropicError(errorResponse, statusCode: httpResponse.statusCode)

                if isRetryable && attempt < configuration.maxRetries {
                    lastError = error

                    // Use Retry-After header if present (429 errors)
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { Double($0) } ?? pow(2.0, Double(attempt))

                    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    continue  // Retry
                } else {
                    throw error
                }
            }

            // Fallback error if can't decode error response
            let fallbackError = AIError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )

            if isRetryable && attempt < configuration.maxRetries {
                lastError = fallbackError
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue  // Retry
            } else {
                throw fallbackError
            }

        } catch let error as AIError {
            // AIError thrown - check if retryable
            if attempt < configuration.maxRetries && error.isRetryable {
                lastError = error
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                continue  // Retry
            } else {
                throw error
            }
        } catch {
            // Unknown error - rethrow immediately
            throw error
        }
    }

    // All retries exhausted
    throw lastError ?? AIError.generationFailed(
        underlying: SendableError(
            NSError(domain: "AnthropicProvider", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "All retry attempts exhausted"
            ])
        )
    )
}
```

**Also need to extend AIError**:
**File**: `/Sources/SwiftAI/Core/Types/AIError.swift`

```swift
extension AIError {
    /// Determines if this error is retryable with exponential backoff.
    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited, .serverError, .timeout:
            return true
        case .authenticationFailed, .invalidInput, .generationFailed, .modelNotCached, .tokenLimitExceeded:
            return false
        }
    }
}
```

### Rationale
The `maxRetries` configuration exists but is never used. Network failures, rate limits, and server errors should be retried with exponential backoff per Anthropic best practices. This dramatically improves reliability.

### Testing
**File**: `/Tests/SwiftAITests/Providers/Anthropic/AnthropicProviderTests.swift`

```swift
@Suite("Anthropic Retry Logic Tests")
struct AnthropicRetryLogicTests {
    @Test("Network error triggers retry")
    func testNetworkErrorRetry() async throws {
        // Mock network failure followed by success
        // Verify request is retried after 1 second delay
    }

    @Test("429 rate limit respects Retry-After header")
    func test429RetryAfter() async throws {
        // Mock 429 with Retry-After: 5
        // Verify wait time matches header
    }

    @Test("500 server error triggers retry")
    func test500Retry() async throws {
        // Mock 500 followed by success
        // Verify exponential backoff (1s, 2s, 4s)
    }

    @Test("400 client error does not retry")
    func test400NoRetry() async throws {
        // Mock 400 invalid_request_error
        // Verify immediate failure, no retry
    }

    @Test("Max retries exhausted throws last error")
    func testMaxRetriesExhausted() async throws {
        // Mock persistent failure
        // Verify retry count matches maxRetries
    }
}
```

### Complexity
**Medium** - 4-6 hours (implementation + testing)

---

## Issue 12.3: Incomplete Streaming - Missing message_delta Events (CRITICAL)

### Source
- **Anthropic Docs**: https://platform.claude.com/docs/en/api/messages (Streaming section)
- **Gap**: Code review finding + sequential thinking analysis

### Current State
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Streaming.swift`
**Lines**: 387-417 (parseStreamEvent method)

```swift
// Current implementation MISSING message_delta event type
internal func parseStreamEvent(from data: Data) throws -> AnthropicStreamEvent? {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = json["type"] as? String else {
        return nil
    }

    switch type {
    case "message_start":
        let event = try decoder.decode(AnthropicStreamEvent.MessageStart.self, from: data)
        return .messageStart(event)

    case "content_block_start":
        let event = try decoder.decode(AnthropicStreamEvent.ContentBlockStart.self, from: data)
        return .contentBlockStart(event)

    case "content_block_delta":
        let event = try decoder.decode(AnthropicStreamEvent.ContentBlockDelta.self, from: data)
        return .contentBlockDelta(event)

    case "content_block_stop":
        return .contentBlockStop

    case "message_stop":
        return .messageStop

    // MISSING: message_delta case!

    default:
        return nil
    }
}
```

**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicAPITypes.swift`
**Lines**: ~200+ (AnthropicStreamEvent enum)

```swift
// Current enum MISSING message_delta case
internal enum AnthropicStreamEvent: Sendable {
    case messageStart(MessageStart)
    case contentBlockStart(ContentBlockStart)
    case contentBlockDelta(ContentBlockDelta)
    case contentBlockStop
    case messageStop
    // MISSING: case messageDelta(MessageDelta)
}
```

### API Specification
According to Anthropic docs, `message_delta` provides:
```json
{
  "type": "message_delta",
  "delta": {
    "stop_reason": "end_turn",
    "stop_sequence": null
  },
  "usage": {
    "input_tokens": 100,
    "output_tokens": 50
  }
}
```

### Proposed Fix

**Step 1**: Add MessageDelta to AnthropicStreamEvent enum
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicAPITypes.swift`

```swift
// Add after contentBlockStop case
internal enum AnthropicStreamEvent: Sendable {
    case messageStart(MessageStart)
    case contentBlockStart(ContentBlockStart)
    case contentBlockDelta(ContentBlockDelta)
    case contentBlockStop
    case messageDelta(MessageDelta)  // NEW
    case messageStop

    // ... existing MessageStart, ContentBlockStart, etc. ...

    // NEW: Message delta structure
    struct MessageDelta: Codable, Sendable {
        let delta: Delta
        let usage: Usage

        struct Delta: Codable, Sendable {
            let stopReason: String?
            let stopSequence: String?

            enum CodingKeys: String, CodingKey {
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
            }
        }

        struct Usage: Codable, Sendable {
            let inputTokens: Int
            let outputTokens: Int

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }
    }
}
```

**Step 2**: Parse message_delta events
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Streaming.swift`
**Lines**: 387-417

```swift
internal func parseStreamEvent(from data: Data) throws -> AnthropicStreamEvent? {
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let type = json["type"] as? String else {
        return nil
    }

    switch type {
    case "message_start":
        let event = try decoder.decode(AnthropicStreamEvent.MessageStart.self, from: data)
        return .messageStart(event)

    case "content_block_start":
        let event = try decoder.decode(AnthropicStreamEvent.ContentBlockStart.self, from: data)
        return .contentBlockStart(event)

    case "content_block_delta":
        let event = try decoder.decode(AnthropicStreamEvent.ContentBlockDelta.self, from: data)
        return .contentBlockDelta(event)

    case "content_block_stop":
        return .contentBlockStop

    case "message_delta":  // NEW
        let event = try decoder.decode(AnthropicStreamEvent.MessageDelta.self, from: data)
        return .messageDelta(event)

    case "message_stop":
        return .messageStop

    default:
        return nil
    }
}
```

**Step 3**: Process message_delta to yield final chunk with usage stats
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Streaming.swift`
**Lines**: 451-479

```swift
internal func processStreamEvent(
    _ event: AnthropicStreamEvent,
    startTime: Date,
    totalTokens: inout Int
) -> GenerationChunk? {
    switch event {
    case .contentBlockDelta(let delta):
        totalTokens += 1
        let duration = Date().timeIntervalSince(startTime)
        let tokensPerSecond = duration > 0 ? Double(totalTokens) / duration : 0

        return GenerationChunk(
            text: delta.delta.text,
            tokenCount: 1,
            tokenId: nil,
            logprob: nil,
            topLogprobs: nil,
            tokensPerSecond: tokensPerSecond,
            isComplete: false,
            finishReason: nil,
            timestamp: Date()
        )

    case .messageDelta(let delta):  // NEW
        // Final chunk with completion metadata
        return GenerationChunk(
            text: "",  // No text in message_delta
            tokenCount: 0,
            tokenId: nil,
            logprob: nil,
            topLogprobs: nil,
            tokensPerSecond: nil,
            isComplete: true,
            finishReason: mapStopReason(delta.delta.stopReason),
            timestamp: Date(),
            usage: UsageStats(
                promptTokens: delta.usage.inputTokens,
                completionTokens: delta.usage.outputTokens
            )
        )

    default:
        return nil
    }
}
```

**Step 4**: Update GenerationChunk to include usage
**File**: `/Sources/SwiftAI/Core/Types/GenerationChunk.swift`

```swift
// Add usage field if not already present
public struct GenerationChunk: Sendable, Hashable {
    public let text: String
    public let tokenCount: Int
    public let tokenId: Int?
    public let logprob: Float?
    public let topLogprobs: [TokenLogprob]?
    public let tokensPerSecond: Double?
    public let isComplete: Bool
    public let finishReason: FinishReason?
    public let timestamp: Date
    public let usage: UsageStats?  // NEW - Optional usage statistics

    public init(
        text: String,
        tokenCount: Int,
        tokenId: Int? = nil,
        logprob: Float? = nil,
        topLogprobs: [TokenLogprob]? = nil,
        tokensPerSecond: Double? = nil,
        isComplete: Bool,
        finishReason: FinishReason? = nil,
        timestamp: Date,
        usage: UsageStats? = nil  // NEW
    ) {
        self.text = text
        self.tokenCount = tokenCount
        self.tokenId = tokenId
        self.logprob = logprob
        self.topLogprobs = topLogprobs
        self.tokensPerSecond = tokensPerSecond
        self.isComplete = isComplete
        self.finishReason = finishReason
        self.timestamp = timestamp
        self.usage = usage  // NEW
    }
}
```

### Rationale
The `message_delta` event provides critical usage statistics during streaming that are currently lost. Without this, users have no way to track token usage for streamed responses.

### Testing
**File**: `/Tests/SwiftAITests/Providers/Anthropic/AnthropicProviderTests.swift`

```swift
@Test("message_delta event provides usage statistics")
func testMessageDeltaUsageStats() throws {
    let json = """
    {
        "type": "message_delta",
        "delta": {
            "stop_reason": "end_turn",
            "stop_sequence": null
        },
        "usage": {
            "input_tokens": 100,
            "output_tokens": 50
        }
    }
    """.data(using: .utf8)!

    let event = try parseStreamEvent(from: json)

    guard case .messageDelta(let delta) = event else {
        Issue.record("Expected messageDelta event")
        return
    }

    #expect(delta.delta.stopReason == "end_turn")
    #expect(delta.usage.inputTokens == 100)
    #expect(delta.usage.outputTokens == 50)

    // Verify chunk generation includes usage
    var totalTokens = 0
    let chunk = processStreamEvent(event, startTime: Date(), totalTokens: &totalTokens)
    #expect(chunk?.isComplete == true)
    #expect(chunk?.usage?.promptTokens == 100)
    #expect(chunk?.usage?.completionTokens == 50)
}
```

### Complexity
**Medium** - 3-4 hours (struct definition + parsing + testing)

---

## Issue 12.4: Add Missing Request Parameters (HIGH)

### Source
- **Anthropic Docs**: https://platform.claude.com/docs/en/api/messages (Request parameters section)

### Current State
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicAPITypes.swift`
**Lines**: ~50-80

```swift
// Current request is MISSING 4 parameters
internal struct AnthropicMessagesRequest: Codable, Sendable {
    let model: String
    let messages: [MessageContent]
    let maxTokens: Int
    let system: String?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    let stream: Bool?
    let thinking: ThinkingRequest?

    // MISSING:
    // - stop_sequences
    // - metadata
    // - service_tier
    // - tool_choice (requires tools to be useful)
}
```

### Proposed Fix

```swift
// File: /Sources/SwiftAI/Providers/Anthropic/AnthropicAPITypes.swift

internal struct AnthropicMessagesRequest: Codable, Sendable {
    let model: String
    let messages: [MessageContent]
    let maxTokens: Int
    let system: String?
    let temperature: Double?
    let topP: Double?
    let topK: Int?
    let stream: Bool?
    let thinking: ThinkingRequest?

    // NEW: Additional parameters
    let stopSequences: [String]?      // Custom stop sequences
    let metadata: Metadata?           // User tracking metadata
    let serviceTier: String?          // "auto", "standard_only"
    let toolChoice: ToolChoice?       // Tool usage behavior (for Phase 13)

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case system
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case stream
        case thinking
        case stopSequences = "stop_sequences"  // NEW
        case metadata                           // NEW
        case serviceTier = "service_tier"       // NEW
        case toolChoice = "tool_choice"         // NEW
    }

    // NEW: Metadata structure
    struct Metadata: Codable, Sendable {
        let userId: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
        }
    }

    // NEW: Tool choice structure (for Phase 13)
    enum ToolChoice: Codable, Sendable {
        case auto
        case any
        case tool(String)
        case none

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .auto:
                try container.encode("auto")
            case .any:
                try container.encode("any")
            case .tool(let name):
                try container.encode(["type": "tool", "name": name])
            case .none:
                try container.encode("none")
            }
        }
    }
}
```

**Update GenerateConfig to support these**:
**File**: `/Sources/SwiftAI/Core/Types/GenerateConfig.swift`

```swift
// Add new properties to GenerateConfig
public struct GenerateConfig: Sendable, Hashable {
    // ... existing properties ...

    // NEW: Additional configuration options
    public var stopSequences: [String]?
    public var userId: String?  // For metadata.user_id
    public var serviceTier: ServiceTier?

    public enum ServiceTier: String, Sendable, Hashable {
        case auto = "auto"
        case standardOnly = "standard_only"
    }

    // NEW: Fluent API methods
    public func stopSequences(_ sequences: [String]) -> Self {
        var copy = self
        copy.stopSequences = sequences
        return copy
    }

    public func userId(_ id: String) -> Self {
        var copy = self
        copy.userId = id
        return copy
    }

    public func serviceTier(_ tier: ServiceTier) -> Self {
        var copy = self
        copy.serviceTier = tier
        return copy
    }
}
```

**Update buildRequestBody to use new parameters**:
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`

```swift
// Around line 138-148
return AnthropicMessagesRequest(
    model: model.rawValue,
    messages: apiMessages,
    maxTokens: config.maxTokens ?? 1024,
    system: systemPrompt,
    temperature: config.temperature >= 0 ? Double(config.temperature) : nil,
    topP: (config.topP > 0 && config.topP <= 1) ? Double(config.topP) : nil,
    topK: config.topK,
    stream: stream ? true : nil,
    thinking: thinkingRequest,
    stopSequences: config.stopSequences,  // NEW
    metadata: config.userId.map { AnthropicMessagesRequest.Metadata(userId: $0) },  // NEW
    serviceTier: config.serviceTier?.rawValue,  // NEW
    toolChoice: nil  // Will be used in Phase 13
)
```

### Rationale
These are documented API parameters that users may need:
- **stop_sequences**: Custom stop tokens for controlled generation
- **metadata.user_id**: Track usage per user for analytics/billing
- **service_tier**: Choose between priority and standard capacity
- **tool_choice**: Control tool usage behavior (implements in Phase 13)

### Testing

```swift
@Test("stop_sequences parameter is sent correctly")
func testStopSequences() throws {
    let config = GenerateConfig.default
        .stopSequences(["END", "STOP"])

    let request = buildRequestBody(
        messages: [.user("Hello")],
        model: .claudeSonnet45,
        config: config
    )

    #expect(request.stopSequences == ["END", "STOP"])
}

@Test("metadata user_id is sent correctly")
func testMetadataUserId() throws {
    let config = GenerateConfig.default
        .userId("user-12345")

    let request = buildRequestBody(
        messages: [.user("Hello")],
        model: .claudeSonnet45,
        config: config
    )

    #expect(request.metadata?.userId == "user-12345")
}

@Test("service_tier parameter is sent correctly")
func testServiceTier() throws {
    let config = GenerateConfig.default
        .serviceTier(.standardOnly)

    let request = buildRequestBody(
        messages: [.user("Hello")],
        model: .claudeSonnet45,
        config: config
    )

    #expect(request.serviceTier == "standard_only")
}
```

### Complexity
**Simple** - 2-3 hours (parameter additions + fluent API + tests)

---

## Issue 12.5: Missing Stop Reasons (HIGH)

### Source
- **Anthropic Docs**: https://platform.claude.com/docs/en/api/messages (stop_reason field)

### Current State
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`
**Lines**: 466-477

```swift
// Current mapping MISSING 3 stop reasons
private func mapStopReason(_ reason: String?) -> FinishReason {
    switch reason {
    case "end_turn":
        return .stop
    case "max_tokens":
        return .maxTokens
    case "stop_sequence":
        return .stopSequence
    default:
        return .stop
    }
    // MISSING: "tool_use", "pause_turn", "refusal"
}
```

### API Specification
Anthropic returns these stop_reason values:
- `end_turn` - Natural completion ✓
- `max_tokens` - Hit token limit ✓
- `stop_sequence` - Hit custom stop sequence ✓
- `tool_use` - Model invoked a tool (MISSING)
- `pause_turn` - Long-running turn paused (MISSING)
- `refusal` - Content blocked by classifiers (MISSING)

### Proposed Fix

**Step 1**: Check if FinishReason enum needs new cases
**File**: `/Sources/SwiftAI/Core/Types/FinishReason.swift`

```swift
// Verify these cases exist, add if missing:
public enum FinishReason: String, Sendable, Hashable, Codable {
    case stop
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"          // Add if missing
    case contentFilter = "content_filter"  // For refusal
    case pauseTurn = "pause_turn"      // Add if missing
}
```

**Step 2**: Update mapStopReason
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`

```swift
private func mapStopReason(_ reason: String?) -> FinishReason {
    switch reason {
    case "end_turn":
        return .stop
    case "max_tokens":
        return .maxTokens
    case "stop_sequence":
        return .stopSequence
    case "tool_use":  // NEW
        return .toolUse
    case "pause_turn":  // NEW
        return .pauseTurn
    case "refusal":  // NEW
        return .contentFilter  // Map refusal to existing contentFilter case
    default:
        return .stop
    }
}
```

### Rationale
These stop reasons are documented in the API and critical for:
- **tool_use**: Detecting when the model wants to call a function (Phase 13)
- **pause_turn**: Handling very long generations that need continuation
- **refusal**: Understanding when content was blocked by safety classifiers

### Testing

```swift
@Test("tool_use stop reason maps correctly")
func testToolUseStopReason() {
    let reason = mapStopReason("tool_use")
    #expect(reason == .toolUse)
}

@Test("pause_turn stop reason maps correctly")
func testPauseTurnStopReason() {
    let reason = mapStopReason("pause_turn")
    #expect(reason == .pauseTurn)
}

@Test("refusal stop reason maps to contentFilter")
func testRefusalStopReason() {
    let reason = mapStopReason("refusal")
    #expect(reason == .contentFilter)
}
```

### Complexity
**Simple** - 30 minutes (enum cases + mapping + tests)

---

## Issue 12.6: Missing Error Types (HIGH)

### Source
- **Anthropic Docs**: https://platform.claude.com/docs/en/api/errors

### Current State
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`
**Lines**: 305-343

```swift
// Current mapping MISSING 2 error types
internal func mapAnthropicError(
    _ error: AnthropicErrorResponse,
    statusCode: Int
) -> AIError {
    switch error.error.type {
    case "invalid_request_error":
        return .invalidInput(error.error.message)
    case "authentication_error":
        return .authenticationFailed(error.error.message)
    case "permission_error":
        return .authenticationFailed(error.error.message)
    case "not_found_error":
        return .invalidInput(error.error.message)
    case "rate_limit_error":
        return .rateLimited(retryAfter: nil)
    case "timeout_error":
        return .timeout(configuration.timeout)
    case "api_error", "overloaded_error":
        return .serverError(statusCode: statusCode, message: error.error.message)
    default:
        let underlyingError = NSError(...)
        return .generationFailed(underlying: SendableError(underlyingError))
    }
    // MISSING: "billing_error" (402), explicit "request_too_large" (413)
}
```

### API Specification
Official error types:
- `invalid_request_error` (400) ✓
- `authentication_error` (401) ✓
- `billing_error` (402) - MISSING
- `permission_error` (403) ✓
- `not_found_error` (404) ✓
- `request_too_large` (413) - Not explicitly handled
- `rate_limit_error` (429) ✓
- `timeout_error` (504) ✓
- `api_error` (500) ✓
- `overloaded_error` (529) ✓

### Proposed Fix

**Step 1**: Check if AIError needs billing case
**File**: `/Sources/SwiftAI/Core/Types/AIError.swift`

```swift
// Add if not present:
public enum AIError: Error, Sendable, LocalizedError {
    // ... existing cases ...
    case billingError(String)  // NEW - for 402 errors

    public var errorDescription: String? {
        switch self {
        // ... existing cases ...
        case .billingError(let message):
            return "Billing error: \(message). Please check your payment method."
        }
    }
}
```

**Step 2**: Update mapAnthropicError
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`

```swift
internal func mapAnthropicError(
    _ error: AnthropicErrorResponse,
    statusCode: Int
) -> AIError {
    switch error.error.type {
    case "invalid_request_error":
        return .invalidInput(error.error.message)

    case "authentication_error":
        return .authenticationFailed(error.error.message)

    case "billing_error":  // NEW
        return .billingError(error.error.message)

    case "permission_error":
        return .authenticationFailed(error.error.message)

    case "not_found_error":
        return .invalidInput(error.error.message)

    case "request_too_large":  // NEW - explicit handling
        return .invalidInput("Request exceeds 32MB size limit. \(error.error.message)")

    case "rate_limit_error":
        return .rateLimited(retryAfter: nil)

    case "timeout_error":
        return .timeout(configuration.timeout)

    case "api_error", "overloaded_error":
        return .serverError(statusCode: statusCode, message: error.error.message)

    default:
        let underlyingError = NSError(
            domain: "com.anthropic.api",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: error.error.message]
        )
        return .generationFailed(underlying: SendableError(underlyingError))
    }
}
```

### Rationale
- **billing_error**: Users need clear feedback about payment issues
- **request_too_large**: Specific error for 32MB limit helps users understand what to fix

### Testing

```swift
@Test("billing_error maps correctly")
func testBillingError() {
    let errorResponse = AnthropicErrorResponse(
        error: .init(type: "billing_error", message: "Payment failed")
    )
    let error = mapAnthropicError(errorResponse, statusCode: 402)

    if case .billingError(let message) = error {
        #expect(message == "Payment failed")
    } else {
        Issue.record("Expected billingError")
    }
}

@Test("request_too_large provides helpful message")
func testRequestTooLarge() {
    let errorResponse = AnthropicErrorResponse(
        error: .init(type: "request_too_large", message: "Request size exceeded")
    )
    let error = mapAnthropicError(errorResponse, statusCode: 413)

    if case .invalidInput(let message) = error {
        #expect(message.contains("32MB"))
    } else {
        Issue.record("Expected invalidInput with size limit")
    }
}
```

### Complexity
**Simple** - 1 hour (enum case + mapping + tests)

---

## Issue 12.7: Extract Rate Limit Headers (HIGH)

### Source
- **Anthropic Docs**: https://platform.claude.com/docs/en/api/rate-limits
- **Code Review**: Warning #1

### Current State
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`
**Lines**: 199-252

```swift
// Currently extracts NO rate limit headers
internal func executeRequest(...) async throws -> AnthropicMessagesResponse {
    // ... request execution ...

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIError.networkError(URLError(.badServerResponse))
    }

    // NO HEADER EXTRACTION - headers are ignored!

    guard (200...299).contains(httpResponse.statusCode) else {
        // ... error handling ...
    }

    return try decoder.decode(AnthropicMessagesResponse.self, from: data)
}
```

### API Specification
Anthropic returns these rate limit headers:
- `request-id` - Unique request identifier for support
- `anthropic-organization-id` - Organization ID
- `RateLimit-Limit-Requests` - Max requests per minute
- `RateLimit-Limit-Tokens` - Max tokens per minute
- `RateLimit-Remaining-Requests` - Remaining requests
- `RateLimit-Remaining-Tokens` - Remaining tokens
- `RateLimit-Reset-Requests` - Reset time for requests
- `RateLimit-Reset-Tokens` - Reset time for tokens
- `Retry-After` - Wait time for 429 errors (seconds)

### Proposed Fix

**Step 1**: Create RateLimitInfo structure
**File**: `/Sources/SwiftAI/Core/Types/RateLimitInfo.swift` (NEW FILE)

```swift
// File: /Sources/SwiftAI/Core/Types/RateLimitInfo.swift

import Foundation

/// Rate limiting information from API response headers.
///
/// Anthropic provides detailed rate limit headers that help clients
/// implement intelligent request pacing and avoid hitting limits.
public struct RateLimitInfo: Sendable, Hashable, Codable {
    /// Unique request identifier for debugging with Anthropic support.
    public let requestId: String?

    /// Organization ID associated with the API key.
    public let organizationId: String?

    /// Maximum requests allowed per minute.
    public let limitRequests: Int?

    /// Maximum tokens allowed per minute.
    public let limitTokens: Int?

    /// Remaining requests in current minute.
    public let remainingRequests: Int?

    /// Remaining tokens in current minute.
    public let remainingTokens: Int?

    /// Timestamp when request limit resets.
    public let resetRequests: Date?

    /// Timestamp when token limit resets.
    public let resetTokens: Date?

    /// Seconds to wait before retrying (429 errors only).
    public let retryAfter: TimeInterval?

    /// Initialize from HTTP response headers.
    public init(headers: [String: String]) {
        self.requestId = headers["request-id"]
        self.organizationId = headers["anthropic-organization-id"]

        self.limitRequests = headers["RateLimit-Limit-Requests"].flatMap(Int.init)
        self.limitTokens = headers["RateLimit-Limit-Tokens"].flatMap(Int.init)

        self.remainingRequests = headers["RateLimit-Remaining-Requests"].flatMap(Int.init)
        self.remainingTokens = headers["RateLimit-Remaining-Tokens"].flatMap(Int.init)

        // Parse RFC 3339 timestamps
        let formatter = ISO8601DateFormatter()
        self.resetRequests = headers["RateLimit-Reset-Requests"].flatMap { formatter.date(from: $0) }
        self.resetTokens = headers["RateLimit-Reset-Tokens"].flatMap { formatter.date(from: $0) }

        self.retryAfter = headers["Retry-After"].flatMap(TimeInterval.init)
    }
}
```

**Step 2**: Add to GenerationResult
**File**: `/Sources/SwiftAI/Core/Types/GenerationResult.swift`

```swift
public struct GenerationResult: Sendable, Hashable {
    // ... existing fields ...
    public let usage: UsageStats?
    public let rateLimitInfo: RateLimitInfo?  // NEW

    public init(
        text: String,
        tokenCount: Int,
        generationTime: TimeInterval,
        tokensPerSecond: Double?,
        finishReason: FinishReason?,
        logprobs: [TokenLogprob]?,
        usage: UsageStats?,
        rateLimitInfo: RateLimitInfo? = nil  // NEW
    ) {
        // ... existing assignments ...
        self.rateLimitInfo = rateLimitInfo  // NEW
    }
}
```

**Step 3**: Extract headers in executeRequest
**File**: `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift`

```swift
internal func executeRequest(
    _ request: AnthropicMessagesRequest
) async throws -> AnthropicMessagesResponse {
    // ... existing request execution ...

    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIError.networkError(URLError(.badServerResponse))
    }

    // NEW: Extract rate limit info
    let rateLimitInfo = RateLimitInfo(
        headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
    )

    guard (200...299).contains(httpResponse.statusCode) else {
        // NEW: Use Retry-After from rate limit info
        if httpResponse.statusCode == 429, let retryAfter = rateLimitInfo.retryAfter {
            if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                throw mapAnthropicError(errorResponse, statusCode: 429, retryAfter: retryAfter)
            }
        }
        // ... rest of error handling ...
    }

    let response = try decoder.decode(AnthropicMessagesResponse.self, from: data)

    // NEW: Attach rate limit info to response (need to modify response struct)
    return response  // Will modify to include rateLimitInfo
}
```

**Step 4**: Store rate limit info for conversion to GenerationResult
This requires either:
- Option A: Make AnthropicMessagesResponse mutable to add rateLimitInfo
- Option B: Pass rateLimitInfo separately through convertToGenerationResult

**Option B (cleaner)**:

```swift
// Update method signature
internal func convertToGenerationResult(
    _ response: AnthropicMessagesResponse,
    startTime: Date,
    rateLimitInfo: RateLimitInfo? = nil  // NEW
) -> GenerationResult {
    // ... existing code ...

    return GenerationResult(
        text: text,
        tokenCount: response.usage.outputTokens,
        generationTime: duration,
        tokensPerSecond: tokensPerSecond,
        finishReason: mapStopReason(response.stopReason),
        logprobs: nil,
        usage: UsageStats(
            promptTokens: response.usage.inputTokens,
            completionTokens: response.usage.outputTokens
        ),
        rateLimitInfo: rateLimitInfo  // NEW
    )
}

// Update generate() to pass rateLimitInfo
public func generate(...) async throws -> GenerationResult {
    let startTime = Date()
    let request = buildRequestBody(...)

    // executeRequest now returns tuple
    let (response, rateLimitInfo) = try await executeRequestWithHeaders(request)

    return convertToGenerationResult(response, startTime: startTime, rateLimitInfo: rateLimitInfo)
}
```

**Step 5**: Update mapAnthropicError signature
```swift
internal func mapAnthropicError(
    _ error: AnthropicErrorResponse,
    statusCode: Int,
    retryAfter: TimeInterval? = nil  // NEW - from rate limit info
) -> AIError {
    switch error.error.type {
    // ... existing cases ...
    case "rate_limit_error":
        return .rateLimited(retryAfter: retryAfter)  // Use extracted value
    // ... rest of cases ...
    }
}
```

### Rationale
Rate limit headers provide critical visibility into:
- **Remaining capacity**: Users can pace requests intelligently
- **Reset times**: Know when limits refresh
- **Request IDs**: Essential for debugging with Anthropic support
- **Retry timing**: Respect server-provided retry delays

### Testing

```swift
@Test("Rate limit headers are extracted correctly")
func testRateLimitHeaderExtraction() {
    let headers = [
        "request-id": "req_123abc",
        "anthropic-organization-id": "org_456def",
        "RateLimit-Limit-Requests": "100",
        "RateLimit-Limit-Tokens": "50000",
        "RateLimit-Remaining-Requests": "95",
        "RateLimit-Remaining-Tokens": "48000",
        "RateLimit-Reset-Requests": "2025-12-26T10:00:00Z",
        "RateLimit-Reset-Tokens": "2025-12-26T10:00:00Z",
        "Retry-After": "30"
    ]

    let info = RateLimitInfo(headers: headers)

    #expect(info.requestId == "req_123abc")
    #expect(info.organizationId == "org_456def")
    #expect(info.limitRequests == 100)
    #expect(info.limitTokens == 50000)
    #expect(info.remainingRequests == 95)
    #expect(info.remainingTokens == 48000)
    #expect(info.resetRequests != nil)
    #expect(info.retryAfter == 30)
}

@Test("GenerationResult includes rate limit info")
func testRateLimitInfoInResult() async throws {
    // Mock HTTP response with rate limit headers
    // Verify GenerationResult.rateLimitInfo is populated
}
```

### Complexity
**Medium** - 4-5 hours (struct definition + extraction + integration + tests)

---

## Phase 12 Summary

### Files Modified
1. `/Sources/SwiftAI/Providers/Anthropic/AnthropicModelID.swift` - Add 6 model IDs
2. `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Helpers.swift` - Retry logic, error mapping, header extraction
3. `/Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Streaming.swift` - message_delta events
4. `/Sources/SwiftAI/Providers/Anthropic/AnthropicAPITypes.swift` - New request parameters, MessageDelta
5. `/Sources/SwiftAI/Core/Types/GenerateConfig.swift` - New configuration options
6. `/Sources/SwiftAI/Core/Types/FinishReason.swift` - New stop reason cases
7. `/Sources/SwiftAI/Core/Types/AIError.swift` - billingError case, isRetryable extension
8. `/Sources/SwiftAI/Core/Types/GenerationResult.swift` - rateLimitInfo field
9. `/Sources/SwiftAI/Core/Types/GenerationChunk.swift` - usage field
10. `/Sources/SwiftAI/Core/Types/RateLimitInfo.swift` - NEW FILE

### Files Created
1. `/Sources/SwiftAI/Core/Types/RateLimitInfo.swift`

### Test Updates
1. `/Tests/SwiftAITests/Providers/Anthropic/AnthropicProviderTests.swift` - 20+ new tests

### Total Effort
**1-2 weeks** (10-15 hours of implementation + 5-8 hours of testing)

### Acceptance Criteria
- [  ] All 6 new model IDs are defined and tested
- [  ] Retry logic implements exponential backoff with configurable maxRetries
- [  ] message_delta events provide usage statistics in streaming
- [  ] All 4 new request parameters (stop_sequences, metadata, service_tier, tool_choice) are supported
- [  ] All 3 new stop reasons (tool_use, pause_turn, refusal) are mapped correctly
- [  ] billing_error and request_too_large errors are handled
- [  ] All 9 rate limit headers are extracted and exposed
- [  ] All new unit tests pass
- [  ] swift build completes without warnings
- [  ] Integration tests confirm API compatibility

---

# Phase 13: Tool Use / Function Calling (HIGH PRIORITY)

**Objective**: Implement complete function calling support for agentic applications
**Effort**: 2-3 weeks
**Dependencies**: Phase 12 (tool_choice parameter, toolUse stop reason)

This phase will be detailed in a follow-up document due to its complexity.

**High-Level Tasks**:
1. Define Tool structures with JSON schema support
2. Implement tool definition API in GenerateConfig
3. Handle tool_use content blocks in responses
4. Support tool_result in conversation history
5. Implement multi-turn tool calling loops
6. Add server tools (web_search)
7. Comprehensive tool use testing

---

# Phase 14: Prompt Caching (HIGH PRIORITY)

**Objective**: Implement prompt caching for 90% cost savings on repeated requests
**Effort**: 1 week
**Dependencies**: Phase 12

**Source**: https://platform.claude.com/docs/en/build-with-claude/prompt-caching

This phase will be detailed in a follow-up document.

**High-Level Tasks**:
1. Add cache_control support on content blocks
2. Implement system prompt as array
3. Add beta header: prompt-caching-2024-07-31
4. Track cache usage statistics
5. Documentation and examples

---

# Phase 15: Document/PDF Support (MEDIUM PRIORITY)

**Objective**: Add document analysis capabilities
**Effort**: 1-2 weeks
**Dependencies**: Phase 12

**Source**: https://platform.claude.com/docs/en/build-with-claude/pdf-support

This phase will be detailed in a follow-up document.

**High-Level Tasks**:
1. Add document content blocks
2. Support PDF base64 and URL sources
3. Implement citations API
4. Add document-specific validation
5. Testing with real PDFs

---

# Phase 16: Advanced APIs (MEDIUM PRIORITY)

**Objective**: Implement Batch, Token Counting, and Models APIs
**Effort**: 2-3 weeks
**Dependencies**: Phase 12

**Source**: https://platform.claude.com/docs/en/api/

This phase will be detailed in a follow-up document.

**High-Level Tasks**:
1. Batch Processing API (50% cost reduction)
2. Token Counting API (pre-calculate costs)
3. Models API (dynamic model listing)
4. Comprehensive testing

---

# Phase 17: Polish & Optimization (LOW PRIORITY)

**Objective**: Complete remaining enhancements
**Effort**: 1 week
**Dependencies**: Phases 12-16

**High-Level Tasks**:
1. Beta headers support
2. Citations API completion
3. Web search results
4. Request size validation
5. Performance optimizations
6. Documentation polish

---

# References

## Official Documentation
1. [Anthropic API - Messages](https://platform.claude.com/docs/en/api/messages)
2. [Anthropic API - Errors](https://platform.claude.com/docs/en/api/errors)
3. [Anthropic API - Getting Started](https://platform.claude.com/docs/en/api/getting-started)
4. [Anthropic Models Overview](https://platform.claude.com/docs/en/about-claude/models/overview)
5. [Anthropic Rate Limits](https://platform.claude.com/docs/en/api/rate-limits)
6. [Anthropic Streaming](https://platform.claude.com/docs/en/build-with-claude/streaming)
7. [Anthropic Extended Thinking](https://platform.claude.com/docs/en/docs/build-with-claude/extended-thinking)
8. [Anthropic Vision](https://platform.claude.com/docs/en/docs/build-with-claude/vision)
9. [Anthropic PDF Support](https://platform.claude.com/docs/en/docs/build-with-claude/pdf-support)
10. [Anthropic Prompt Caching](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching)
11. [Anthropic Tool Use](https://platform.claude.com/docs/en/docs/build-with-claude/tool-use)
12. [Anthropic Batch API](https://platform.claude.com/docs/en/build-with-claude/batch-processing)

## Reference Implementations
1. [SwiftAnthropic SDK](https://github.com/jamesrochabrun/SwiftAnthropic)
2. [SwiftClaude SDK](https://github.com/GeorgeLyon/SwiftClaude)

## Internal Documents
1. CONTEXT_RECOVERY_ANTHROPIC.md
2. ANTHROPIC_PROGRESS.md
3. ANTHROPIC_ENHANCEMENTS_PLAN.md (this document)

---

**Document Version**: 1.0
**Last Updated**: 2025-12-26
**Status**: Phase 12 Ready for Implementation
