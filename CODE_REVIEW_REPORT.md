# SwiftAI Code Review Report

**Branch**: `feature/structured-output-and-tools`
**Review Date**: December 28, 2025
**Files Changed**: 23 files (+2,287 / -1,389 lines)
**Reviewers**: 14 specialized code review agents

---

## Executive Summary

This comprehensive code review analyzed the structured output and tool calling feature implementation. The review identified **18 issues** requiring attention:

| Severity | Count | Action Required |
|----------|-------|-----------------|
| Critical | 5 | Must fix before merge |
| High | 7 | Should fix soon |
| Medium | 6 | Technical debt |

**Overall Assessment**: The implementation demonstrates solid architectural foundations with actor-based concurrency, comprehensive error handling, and multi-backend support. However, several critical issues around Swift 6 concurrency compliance and incomplete integrations need resolution before production use.

---

## Table of Contents

1. [Critical Issues](#critical-issues)
2. [High Priority Issues](#high-priority-issues)
3. [Medium Priority Issues](#medium-priority-issues)
4. [Clone Reference Comparison](#clone-reference-comparison)
5. [Strengths Identified](#strengths-identified)
6. [Recommended Action Items](#recommended-action-items)
7. [Files Reviewed](#files-reviewed)

---

## Critical Issues

### CRIT-001: Actor Isolation Violation in TextEmbeddingCache

**Confidence**: 100%
**File**: `Sources/SwiftAI/Providers/MLX/TextEmbeddingCache.swift:182-207`
**Category**: Concurrency Safety

**Issue**:
The `get()`, `put()`, and `clear()` methods are marked `nonisolated` but return/accept `MLXArray` which is NOT Sendable. This creates data race conditions when multiple concurrent callers access the cache.

**Code**:
```swift
public nonisolated func get(_ key: CacheKey) -> MLXArray? {
    let wrapper = KeyWrapper(key)
    return cacheWrapper.cache.object(forKey: wrapper)?.embedding  // MLXArray is NOT Sendable!
}

public nonisolated func put(_ embedding: MLXArray, forKey key: CacheKey) {
    // ...
}
```

**Impact**:
- Data races when MLXArray crosses actor boundaries
- Undefined behavior under Swift 6 strict concurrency
- Potential crashes or corrupted data

**Fix**:
```swift
// Remove nonisolated - let actor isolation protect the non-Sendable return
public func get(_ key: CacheKey) -> MLXArray? {
    let wrapper = KeyWrapper(key)
    return cacheWrapper.cache.object(forKey: wrapper)?.embedding
}

// Update all call sites to use await
let embedding = await cache.get(key)
```

**Related**: Also update `EmbeddingWrapper` and `KeyWrapper` to be `@unchecked Sendable`.

---

### CRIT-002: Missing Tool Support in Anthropic API Request

**Confidence**: 95%
**File**: `Sources/SwiftAI/Providers/Anthropic/AnthropicAPITypes.swift`
**Category**: Feature Completeness

**Issue**:
The `AnthropicMessagesRequest` struct lacks `tools` and `tool_choice` fields. Tools configured via `GenerateConfig.tools()` are silently ignored when making Anthropic API requests.

**Evidence**:
- `GenerateConfig.swift:196-204` defines `tools` and `toolChoice` properties
- `Schema+ProviderConversion.swift:164-169` provides `toAnthropicFormat()`
- `AnthropicMessagesRequest` has no corresponding fields

**Impact**:
- Tool calling functionality is completely broken for Anthropic provider
- Users will configure tools but they won't be sent to the API
- No error or warning is raised

**Fix**:
```swift
// Add to AnthropicMessagesRequest struct
public struct AnthropicMessagesRequest: Codable {
    // ... existing fields ...
    let tools: [[String: Any]]?
    let toolChoice: [String: Any]?

    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case tools
        case toolChoice = "tool_choice"
    }
}
```

---

### CRIT-003: Memory Safety - No Secure Cleanup of API Keys

**Confidence**: 100%
**Files**:
- `Sources/SwiftAI/Providers/Anthropic/AnthropicAuthentication.swift:41`
- `Sources/SwiftAI/Providers/OpenAI/OpenAIAuthentication.swift:66,78`
**Category**: Security

**Issue**:
API keys are stored as `String` types without any mechanism for secure memory cleanup. When deallocated, credentials remain in memory until overwritten. Combined with `Codable` conformance, credentials can be accidentally serialized.

**Code**:
```swift
// AnthropicAuthentication.swift:41
case apiKey(String)  // Key persists in memory

// OpenAIAuthentication.swift:66
case bearer(String)  // Token persists in memory
```

**Impact**:
- API keys persist in memory after use
- Memory dumps, debugger inspection, or crashes can expose credentials
- `Codable` conformance allows accidental serialization to disk/network

**Recommendations**:
1. Document the limitation clearly in security documentation
2. Consider removing `Codable` conformance from authentication types
3. For production, recommend Keychain for credential storage
4. Add custom `encode(to:)` that throws or redacts credentials if Codable is needed

---

### CRIT-004: Macro Missing nonisolated in Generated Code

**Confidence**: 80%
**File**: `Sources/SwiftAIMacros/GenerableMacro.swift` (multiple locations)
**Category**: Swift 6 Concurrency

**Issue**:
The generated `Partial` struct and its methods lack `nonisolated` annotations. Without these, the methods cannot be called from actors without `await`, defeating the purpose of `Sendable` conformance.

**Current Generation**:
```swift
public struct Partial: GenerableContentConvertible, Sendable {
    public var generableContent: StructuredContent { ... }
}
```

**Expected Generation** (from clone reference):
```swift
nonisolated extension AllTypes: SwiftAI.Generable {
    public nonisolated struct Partial: SwiftAI.GenerableContentConvertible, Sendable {
        public nonisolated var generableContent: StructuredContent { ... }
        public nonisolated init(from structuredContent: StructuredContent) throws { ... }
    }
}
```

**Impact**:
- Ergonomic issues when calling from actors
- Potential compilation errors in Swift 6 strict mode

**Fix**:
Add `nonisolated` to all generated declarations in the macro expansion code.

---

### CRIT-005: Macro Unconditional Sendable Conformance

**Confidence**: 100%
**File**: `Sources/SwiftAIMacros/GenerableMacro.swift:247`
**Category**: Swift 6 Concurrency

**Issue**:
The generated `Partial` struct declares `Sendable` conformance unconditionally without validating that all property types actually conform to `Sendable`.

**Code**:
```swift
public struct Partial: GenerableContentConvertible, Sendable {
    // Properties may not be Sendable!
}
```

**Failure Case**:
```swift
class NonSendableClass {} // Not Sendable

@Generable
struct MyStruct {
    let data: NonSendableClass  // Error: Partial cannot be Sendable
}
```

**Impact**:
- Compilation errors in Swift 6 strict concurrency mode
- Silent failures if concurrency checking is not enabled

**Fix Options**:
1. Remove `Sendable` conformance and let it be inferred conditionally
2. Add diagnostic check in macro to ensure all property types are Sendable
3. Use conditional conformance: `extension Partial: Sendable where ...`

---

## High Priority Issues

### HIGH-001: JsonRepair Mismatched Bracket Handling

**Confidence**: 95%
**File**: `Sources/SwiftAI/Utilities/JsonRepair.swift:162-169`
**Category**: Correctness

**Issue**:
The bracket matching logic only checks if the last item on the stack matches before removing it. Mismatched brackets like `{]` or `[}` are silently ignored, producing invalid JSON.

**Code**:
```swift
case "}":
    if bracketStack.last == .brace {
        bracketStack.removeLast()
    }
    // If last is .bracket, nothing happens - mismatch ignored!
```

**Example**:
- Input: `{"arr": [}`
- Result: `{"arr": [}]}` (invalid JSON - nesting violated)

**Impact**:
- Repaired JSON may still be invalid
- Downstream parsing will fail unexpectedly

**Fix**:
Detect mismatches and either pop the mismatched item or insert the correct closing bracket first.

---

### HIGH-002: Streaming Unbounded Memory Accumulation

**Confidence**: 95%
**File**: `Sources/SwiftAI/Providers/Extensions/TextGenerator+StructuredStreaming.swift:57-74`
**Category**: Memory Management

**Issue**:
The `accumulated` string buffer grows indefinitely (up to 1MB limit) and is never cleared after successful partial parsing. The complete buffer is held in memory even after parsing.

**Code**:
```swift
var accumulated = ""
accumulated.reserveCapacity(4096)
// ...
accumulated += chunk  // Grows to 1MB, never trimmed
```

**Impact**:
- Memory pressure for large responses
- Unnecessary retention of already-parsed content

**Fix**:
After successful parsing and yielding, consider clearing or trimming portions of the buffer that represent complete, already-yielded structures.

---

### HIGH-003: Streaming Excessive Equality Checks

**Confidence**: 90%
**File**: `Sources/SwiftAI/Providers/Extensions/TextGenerator+StructuredStreaming.swift:85-89`
**Category**: Performance

**Issue**:
Full deep equality comparison of `StructuredContent` values on every successful parse to avoid duplicate yields. For large JSON (approaching 1MB), this is O(n) per parse.

**Code**:
```swift
let currentContent = partial.generableContent
if lastParsedContent != currentContent {  // Deep comparison every time
    lastParsedContent = currentContent
    continuation.yield(partial)
}
```

**Impact**:
- CPU overhead proportional to response size × parse count
- For 500KB JSON parsed 50 times: ~25MB of comparisons

**Fix**:
Use hash-based comparison or sequence numbering instead of deep equality:
```swift
let currentHash = currentContent.hashValue
if lastHash != currentHash {
    lastHash = currentHash
    continuation.yield(partial)
}
```

---

### HIGH-004: AIToolExecutor Dead Validation Code

**Confidence**: 85%
**File**: `Sources/SwiftAI/Core/Tools/AIToolExecutor.swift:171-177`
**Category**: Code Quality

**Issue**:
The validation guard checking `results.count == toolCalls.count` can never be false. If a task throws, `withThrowingTaskGroup` propagates the error immediately before this line is reached.

**Code**:
```swift
// This guard can NEVER fail:
guard results.count == toolCalls.count else {
    throw AIToolError.executionFailed(
        tool: "batch",
        underlying: CancellationError()
    )
}
```

**Impact**:
- Dead code that gives false confidence about error handling
- Misleading comments about partial completion scenarios

**Fix**:
Remove the unreachable guard statement, or if partial results are desired, use non-throwing task group with `Result` types.

---

### HIGH-005: Package.swift Version Mismatches

**Confidence**: 95%
**File**: `Package.swift:19-21`
**Category**: Dependencies

**Issue**:
Declared minimum versions don't match Package.resolved:

| Package | Declared | Resolved | Gap |
|---------|----------|----------|-----|
| mlx-swift | 0.21.0 | 0.29.1 | 8 minor versions |
| mlx-swift-lm | 2.29.0 | 2.29.2 | 2 patch versions |
| swift-huggingface | 0.4.0 | 0.5.0 | 1 minor version |

**Impact**:
- Potential breaking API changes between declared and actual versions
- Clean builds may resolve different versions
- `@preconcurrency import MLX` depends on MLX's concurrency behavior

**Fix**:
```swift
.package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.29.1"),
.package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.2"),
.package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.5.0"),
```

---

### HIGH-006: ToolChoice.none Incorrectly Mapped for Anthropic

**Confidence**: 90%
**File**: `Sources/SwiftAI/Providers/Extensions/Schema+ProviderConversion.swift:202`
**Category**: Correctness

**Issue**:
`ToolChoice.none` is mapped to `["type": "auto"]` for Anthropic, which contradicts the semantic meaning. `.none` should mean "don't use tools" but sends "auto" (maybe use tools).

**Code**:
```swift
case .none:
    // Anthropic doesn't have explicit "none" - omit tools instead
    return ["type": "auto"]  // Wrong - sends auto instead of disabling
```

**Impact**:
- Users specifying `.none` will have tools enabled
- Semantic mismatch between intent and behavior

**Fix**:
Return a special marker value that the caller interprets as "omit tool_choice entirely" or throw an error if `.none` is used with Anthropic.

---

### HIGH-007: Schema Optional Types Missing Null Representation

**Confidence**: 85%
**File**: `Sources/SwiftAI/Providers/Extensions/Schema+ProviderConversion.swift:79-82`
**Category**: Correctness

**Issue**:
The `.optional` case returns the wrapped schema directly without indicating nullability in JSON Schema. Per JSON Schema spec, optional values should include null type.

**Code**:
```swift
case .optional(let wrapped):
    // For optional, we return the inner type
    // The optionality is handled by not including in "required"
    return wrapped.toJSONSchema()  // Loses nullability info
```

**Impact**:
- Providers won't know the field can be null
- Schema validation may fail or generate incorrect values

**Fix**:
```swift
case .optional(let wrapped):
    var innerSchema = wrapped.toJSONSchema()
    if let type = innerSchema["type"] as? String {
        innerSchema["type"] = [type, "null"]
    }
    return innerSchema
```

---

## Medium Priority Issues

### MED-001: Test Race Condition in Concurrent Execution Test

**Confidence**: 95%
**File**: `Tests/SwiftAITests/Core/AIToolExecutorTests.swift:465-498`
**Category**: Test Reliability

**Issue**:
The `resultsMaintainOrder()` test uses timing delays (50ms, 20ms, 10ms) that are too small for reliable CI execution. These delays are at the threshold of scheduling jitter.

**Fix**:
Increase delays to at least 100ms intervals or use explicit synchronization primitives instead of sleep-based timing.

---

### MED-002: Meaningless NSCache Eviction Test

**Confidence**: 98%
**File**: `Tests/SwiftAITests/Providers/MLX/TextEmbeddingCacheTests.swift:203-210`
**Category**: Test Quality

**Issue**:
The assertion `#expect(misses >= 0)` always passes - it literally cannot fail.

**Code**:
```swift
#expect(misses >= 0)  // Always true - provides no value
```

**Fix**:
Either remove this test entirely (NSCache behavior is Apple's implementation detail) or test something deterministic.

---

### MED-003: StreamingResult.reduce() Naming Convention

**Confidence**: 90%
**File**: `Sources/SwiftAI/Core/Streaming/StreamingResult.swift:89-127`
**Category**: API Design

**Issue**:
The method name `reduce` suggests accumulation semantics (like `Array.reduce`), but the method actually iterates with a handler and returns the final value. This violates Swift API naming conventions.

**Recommendation**:
Rename to `observe(with:)` or `onEach(_:)` to better reflect iteration behavior.

---

### MED-004: Missing Cancellation Tests for StreamingResult

**Confidence**: 87%
**File**: `Tests/SwiftAITests/Core/StreamingResultTests.swift`
**Category**: Test Coverage

**Issue**:
No tests verify cancellation handling during `collect()`, `reduce()`, or `reduceOnMain()`. Long-running streams should respect Task cancellation.

**Fix**:
Add tests that cancel during iteration and verify proper cleanup and error propagation.

---

### MED-005: JsonRepair No Maximum Depth Protection

**Confidence**: 82%
**File**: `Sources/SwiftAI/Utilities/JsonRepair.swift:138-139`
**Category**: Security

**Issue**:
The `bracketStack` array has no maximum depth limit. Deeply-nested JSON could cause excessive memory allocation.

**Fix**:
Add a reasonable depth limit (e.g., 100 levels) and throw an error when exceeded.

---

### MED-006: Streaming Silent Partial Conversion Failures

**Confidence**: 90%
**File**: `Sources/SwiftAI/Providers/Extensions/TextGenerator+StructuredStreaming.swift:91-93`
**Category**: Error Handling

**Issue**:
Errors during partial conversion to `T.Partial` are silently swallowed. If JSON parses but schema mismatches, the error is lost.

**Code**:
```swift
} catch {
    // Parsing to Partial failed, continue accumulating
}
```

**Impact**:
- Schema mismatches are invisible until final parse
- Debugging is extremely difficult
- Resources wasted on data that will never parse

**Recommendation**:
Track conversion failures and throw after N consecutive failures, or log in DEBUG mode.

---

## Clone Reference Comparison

### Feature Comparison Matrix

| Feature | Our Implementation | Clone Reference | Assessment |
|---------|-------------------|-----------------|------------|
| **Macro: Struct Support** | ✅ Yes | ✅ Yes | Parity |
| **Macro: Enum Support** | ❌ No | ✅ Yes | Clone better |
| **Macro: SwiftFormat** | ❌ No | ✅ Yes | Clone better |
| **Macro: nonisolated** | ❌ Missing | ✅ Yes | Clone better |
| **Tool Execution** | ✅ Centralized executor | ✅ Session-embedded | Different approaches |
| **Tool Concurrent Exec** | ✅ TaskGroup | ❌ Sequential | Ours better |
| **Provider Integration** | ⚠️ Decoupled, incomplete | ✅ Fully integrated | Clone better |
| **Error Handling** | ✅ 20+ categorized errors | ❌ 2 simple cases | Ours better |
| **Multi-Backend** | ✅ 5 backends | ❌ 2 backends | Ours better |
| **Actor Safety** | ✅ Actor-based | ❌ No isolation | Ours better |
| **Authentication** | ✅ Type-safe, secure | ✅ SDK-based | Comparable |
| **Session Pattern** | ❌ No sessions | ✅ Built-in | Clone better |

### Key Architectural Differences

#### Tool Execution
- **Ours**: Centralized `AIToolExecutor` actor - supports concurrent execution, reusable across sessions
- **Clone**: Session-embedded - tools bound to conversation, simpler but sequential only

#### Provider Architecture
- **Ours**: Actor-based with protocol composition (`AIProvider`, `TextGenerator`, etc.)
- **Clone**: Protocol-oriented with sessions (`LLM`, `LLMSession`)

#### Macro System
- **Clone**: 1,257 lines with enum support, SwiftFormat integration, comprehensive validation
- **Ours**: 323 lines, struct-only, string interpolation, basic validation

### Recommended Adoptions from Clone

1. **Add Enum Support** to `@Generable` macro
2. **Integrate SwiftFormat** for generated code quality
3. **Add `nonisolated` Keywords** to all generated declarations
4. **Adopt Adapter Pattern** for provider-specific tool integration
5. **Add Array-of-Optional Validation** (`[String?]` should error)

---

## Strengths Identified

### Security
1. **Constant-Time Comparison**: Authentication properly prevents timing attacks
2. **Credential Redaction**: Debug output properly hides API keys via `debugDescription`
3. **No Credential Logging**: No logging statements expose credentials

### Architecture
4. **Actor-Based Providers**: Thread-safe by design
5. **Comprehensive Error Types**: 20+ categorized errors with recovery suggestions
6. **Multi-Backend Support**: Single OpenAI provider handles OpenAI, OpenRouter, Ollama, Azure
7. **Cancellation Support**: Proper `Task.checkCancellation()` throughout

### Code Quality
8. **Documentation**: Extensive doc comments with examples
9. **Type Safety**: Strong typing with associated types and generics
10. **Sendable Compliance**: Proper `@Sendable` and actor isolation (except noted issues)

---

## Recommended Action Items

### Before Merge (Critical)

| Priority | Issue | File | Effort |
|----------|-------|------|--------|
| P0 | Fix TextEmbeddingCache actor isolation | TextEmbeddingCache.swift | Medium |
| P0 | Add tools/tool_choice to Anthropic request | AnthropicAPITypes.swift | Low |
| P0 | Add nonisolated to macro-generated code | GenerableMacro.swift | Medium |
| P0 | Fix/document API key memory safety | Authentication files | Low |
| P0 | Add Sendable validation to macro | GenerableMacro.swift | Medium |

### Soon After Merge (High)

| Priority | Issue | File | Effort |
|----------|-------|------|--------|
| P1 | Update Package.swift version constraints | Package.swift | Low |
| P1 | Fix JsonRepair bracket handling | JsonRepair.swift | Medium |
| P1 | Optimize streaming memory usage | TextGenerator+StructuredStreaming.swift | Medium |
| P1 | Remove dead AIToolExecutor validation | AIToolExecutor.swift | Low |
| P1 | Fix ToolChoice.none mapping | Schema+ProviderConversion.swift | Low |
| P1 | Add null to optional schemas | Schema+ProviderConversion.swift | Low |
| P1 | Complete tool execution provider integration | Provider files | High |

### Technical Debt (Medium)

| Priority | Issue | File | Effort |
|----------|-------|------|--------|
| P2 | Add enum support to @Generable | GenerableMacro.swift | High |
| P2 | Integrate SwiftFormat for generated code | GenerableMacro.swift | Medium |
| P2 | Fix test timing reliability | AIToolExecutorTests.swift | Low |
| P2 | Remove meaningless NSCache test | TextEmbeddingCacheTests.swift | Low |
| P2 | Rename StreamingResult.reduce() | StreamingResult.swift | Low |
| P2 | Add cancellation tests | StreamingResultTests.swift | Medium |

---

## Files Reviewed

### Core Implementation
- `Sources/SwiftAI/Core/Streaming/StreamingResult.swift`
- `Sources/SwiftAI/Core/Tools/AIToolExecutor.swift`
- `Sources/SwiftAI/Core/Types/GenerateConfig.swift`
- `Sources/SwiftAI/Core/Types/Schema.swift`
- `Sources/SwiftAI/Core/Types/Constraint.swift`
- `Sources/SwiftAI/Core/Protocols/AITool.swift`
- `Sources/SwiftAI/Core/Protocols/Generable.swift`
- `Sources/SwiftAI/Core/Errors/AIError.swift`

### Providers
- `Sources/SwiftAI/Providers/Anthropic/AnthropicAuthentication.swift`
- `Sources/SwiftAI/Providers/Anthropic/AnthropicProvider+Streaming.swift`
- `Sources/SwiftAI/Providers/Anthropic/AnthropicAPITypes.swift`
- `Sources/SwiftAI/Providers/OpenAI/OpenAIAuthentication.swift`
- `Sources/SwiftAI/Providers/OpenAI/OpenAIConfiguration.swift`
- `Sources/SwiftAI/Providers/Extensions/TextGenerator+StructuredStreaming.swift`
- `Sources/SwiftAI/Providers/Extensions/Schema+ProviderConversion.swift`
- `Sources/SwiftAI/Providers/MLX/TextEmbeddingCache.swift`

### Macros
- `Sources/SwiftAIMacros/GenerableMacro.swift`
- `Sources/SwiftAIMacros/GuideMacro.swift`
- `Sources/SwiftAIMacros/SwiftAIMacrosPlugin.swift`
- `Sources/SwiftAI/Core/Macros/GenerableMacros.swift`

### Utilities
- `Sources/SwiftAI/Utilities/JsonRepair.swift`

### Tests
- `Tests/SwiftAITests/Core/AIToolExecutorTests.swift`
- `Tests/SwiftAITests/Core/JsonRepairTests.swift`
- `Tests/SwiftAITests/Core/StreamingResultTests.swift`
- `Tests/SwiftAITests/Core/ProtocolCompilationTests.swift`
- `Tests/SwiftAITests/Providers/MLX/TextEmbeddingCacheTests.swift`
- `Tests/SwiftAITests/MLXModelCacheTests.swift`

### Configuration
- `Package.swift`
- `Package.resolved`

### Clone Reference (for comparison)
- `clone/Sources/SwiftAI/Core/LLM.swift`
- `clone/Sources/SwiftAI/Core/Tool.swift`
- `clone/Sources/SwiftAI/Core/Generable.swift`
- `clone/Sources/SwiftAI/Core/Schema.swift`
- `clone/Sources/SwiftAIMacros/GenerableMacro.swift`
- `clone/Sources/SwiftAI/Backends/Openai/OpenaiSession.swift`
- `clone/Sources/SwiftAI/Backends/Apple/ToolAdapter.swift`

---

## Appendix: Issue Quick Reference

```
CRIT-001  TextEmbeddingCache actor isolation        [Concurrency]   [Must Fix]
CRIT-002  Missing Anthropic tools support           [Feature]       [Must Fix]
CRIT-003  API key memory safety                     [Security]      [Must Fix]
CRIT-004  Macro missing nonisolated                 [Concurrency]   [Must Fix]
CRIT-005  Macro unconditional Sendable              [Concurrency]   [Must Fix]

HIGH-001  JsonRepair bracket mismatch               [Correctness]   [Should Fix]
HIGH-002  Streaming memory accumulation             [Memory]        [Should Fix]
HIGH-003  Streaming equality checks                 [Performance]   [Should Fix]
HIGH-004  AIToolExecutor dead code                  [Code Quality]  [Should Fix]
HIGH-005  Package.swift versions                    [Dependencies]  [Should Fix]
HIGH-006  ToolChoice.none mapping                   [Correctness]   [Should Fix]
HIGH-007  Optional schema null type                 [Correctness]   [Should Fix]

MED-001   Test race condition                       [Test Quality]  [Tech Debt]
MED-002   Meaningless NSCache test                  [Test Quality]  [Tech Debt]
MED-003   StreamingResult.reduce() naming           [API Design]    [Tech Debt]
MED-004   Missing cancellation tests                [Test Coverage] [Tech Debt]
MED-005   JsonRepair max depth                      [Security]      [Tech Debt]
MED-006   Silent partial conversion failures        [Error Handling][Tech Debt]
```

---

*Report generated by 14 specialized code review agents analyzing security, concurrency, performance, correctness, API design, testing, and architectural patterns.*
