// AIToolCallValidationTests.swift
// Conduit Tests
//
// Tests for AIToolCall tool name validation and edge cases.

import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("AIToolCall Validation Tests")
struct AIToolCallValidationTests {

    // MARK: - Empty Tool Name Tests

    @Suite("Empty Tool Name")
    struct EmptyToolNameTests {

        @Test("Empty tool name throws validation error")
        func emptyToolNameThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Empty tool name error has correct reason")
        func emptyToolNameErrorHasCorrectReason() {
            do {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "",
                    argumentsJSON: "{}"
                )
                Issue.record("Expected AIError.invalidToolName to be thrown")
            } catch let error as AIError {
                if case .invalidToolName(let name, let reason) = error {
                    #expect(name.isEmpty)
                    #expect(reason.localizedStandardContains("empty"))
                } else {
                    Issue.record("Expected invalidToolName error, got \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }

        @Test("Empty tool name with StructuredContent init throws error")
        func emptyToolNameWithStructuredContentThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "",
                    arguments: .object([:])
                )
            }
        }
    }

    // MARK: - Invalid Character Tests

    @Suite("Invalid Characters")
    struct InvalidCharacterTests {

        @Test("Tool name with spaces throws error")
        func toolNameWithSpacesThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get weather",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with leading space throws error")
        func toolNameWithLeadingSpaceThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: " get_weather",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with trailing space throws error")
        func toolNameWithTrailingSpaceThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather ",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with dot throws error")
        func toolNameWithDotThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get.weather",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with at symbol throws error")
        func toolNameWithAtSymbolThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "tool@name",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with slash throws error")
        func toolNameWithSlashThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "path/to/tool",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with newline throws error")
        func toolNameWithNewlineThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get\nweather",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with unicode characters throws error")
        func toolNameWithUnicodeThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weath\u{00E9}r",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Tool name with emoji throws error")
        func toolNameWithEmojiThrowsError() {
            #expect(throws: AIError.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "weather_tool_\u{2600}",
                    argumentsJSON: "{}"
                )
            }
        }

        @Test("Invalid character error contains reason")
        func invalidCharacterErrorContainsReason() {
            do {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "invalid tool",
                    argumentsJSON: "{}"
                )
                Issue.record("Expected AIError.invalidToolName to be thrown")
            } catch let error as AIError {
                if case .invalidToolName(let name, let reason) = error {
                    #expect(name == "invalid tool")
                    #expect(reason.localizedStandardContains("alphanumeric"))
                } else {
                    Issue.record("Expected invalidToolName error, got \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - Valid Tool Name Tests

    @Suite("Valid Tool Names")
    struct ValidToolNameTests {

        @Test("Alphanumeric tool name succeeds")
        func alphanumericToolNameSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "getWeather",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "getWeather")
        }

        @Test("Tool name with underscores succeeds")
        func toolNameWithUnderscoresSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "get_weather_forecast",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "get_weather_forecast")
        }

        @Test("Tool name with hyphens succeeds")
        func toolNameWithHyphensSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "get-weather-forecast",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "get-weather-forecast")
        }

        @Test("Tool name with mixed characters succeeds")
        func toolNameWithMixedCharactersSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "get_Weather-Forecast_v2",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "get_Weather-Forecast_v2")
        }

        @Test("Tool name starting with number succeeds")
        func toolNameStartingWithNumberSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "3d_render",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "3d_render")
        }

        @Test("Single character tool name succeeds")
        func singleCharacterToolNameSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "x",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "x")
        }

        @Test("Tool name with only underscores succeeds")
        func toolNameWithOnlyUnderscoresSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "___",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "___")
        }

        @Test("Tool name with only hyphens succeeds")
        func toolNameWithOnlyHyphensSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "---",
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == "---")
        }

        @Test("Long tool name succeeds")
        func longToolNameSucceeds() throws {
            let longName = String(repeating: "a", count: 256)
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: longName,
                argumentsJSON: "{}"
            )
            #expect(toolCall.toolName == longName)
        }
    }

    // MARK: - JSON Decoding Validation Tests

    @Suite("JSON Decoding Validation")
    struct JSONDecodingValidationTests {

        @Test("Decoding with empty tool name throws error")
        func decodingEmptyToolNameThrowsError() {
            let json = """
            {
                "id": "call_123",
                "tool_name": "",
                "arguments": "{}"
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: AIError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Decoding with invalid tool name throws error")
        func decodingInvalidToolNameThrowsError() {
            let json = """
            {
                "id": "call_123",
                "tool_name": "invalid tool",
                "arguments": "{}"
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: AIError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Decoding with valid tool name succeeds")
        func decodingValidToolNameSucceeds() throws {
            let json = """
            {
                "id": "call_123",
                "tool_name": "get_weather",
                "arguments": "{}"
            }
            """
            let data = json.data(using: .utf8)!

            let toolCall = try JSONDecoder().decode(AIToolCall.self, from: data)
            #expect(toolCall.toolName == "get_weather")
        }
    }

    // MARK: - Missing/Null Field Handling Tests

    @Suite("Missing and Null Field Handling")
    struct MissingNullFieldTests {

        @Test("Missing id field throws DecodingError")
        func missingIdFieldThrowsError() {
            let json = """
            {
                "tool_name": "get_weather",
                "arguments": "{}"
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Missing tool_name field throws DecodingError")
        func missingToolNameFieldThrowsError() {
            let json = """
            {
                "id": "call_123",
                "arguments": "{}"
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Missing arguments field throws DecodingError")
        func missingArgumentsFieldThrowsError() {
            let json = """
            {
                "id": "call_123",
                "tool_name": "get_weather"
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Null id field throws DecodingError")
        func nullIdFieldThrowsError() {
            let json = """
            {
                "id": null,
                "tool_name": "get_weather",
                "arguments": "{}"
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Null tool_name field throws DecodingError")
        func nullToolNameFieldThrowsError() {
            let json = """
            {
                "id": "call_123",
                "tool_name": null,
                "arguments": "{}"
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Null arguments field throws DecodingError")
        func nullArgumentsFieldThrowsError() {
            let json = """
            {
                "id": "call_123",
                "tool_name": "get_weather",
                "arguments": null
            }
            """
            let data = json.data(using: .utf8)!

            #expect(throws: Error.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }

        @Test("Empty JSON object throws DecodingError")
        func emptyJSONObjectThrowsError() {
            let json = "{}"
            let data = json.data(using: .utf8)!

            #expect(throws: DecodingError.self) {
                _ = try JSONDecoder().decode(AIToolCall.self, from: data)
            }
        }
    }

    // MARK: - Malformed JSON Arguments Tests

    @Suite("Malformed JSON Arguments")
    struct MalformedJSONArgumentsTests {

        @Test("Unclosed brace in arguments string throws error")
        func unclosedBraceThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    argumentsJSON: #"{"city": "SF""#
                )
            }
        }

        @Test("Extra closing brace in arguments string throws error")
        func extraClosingBraceThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    argumentsJSON: #"{"city": "SF"}}"#
                )
            }
        }

        @Test("Invalid escape sequence in arguments throws error")
        func invalidEscapeSequenceThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    // Invalid escape: \x is not valid JSON escape
                    argumentsJSON: #"{"city": "\x00"}"#
                )
            }
        }

        @Test("Unquoted string value in arguments throws error")
        func unquotedStringValueThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    argumentsJSON: #"{"city": SF}"#
                )
            }
        }

        @Test("Trailing comma in arguments is handled gracefully")
        func trailingCommaIsHandledGracefully() throws {
            // Note: Some JSON parsers handle trailing commas gracefully
            // This tests that we don't crash on slightly malformed JSON
            // The behavior may vary based on the underlying JSON parser
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "get_weather",
                argumentsJSON: #"{"city": "SF",}"#
            )
            #expect(toolCall.toolName == "get_weather")
        }

        @Test("Single quotes instead of double quotes throws error")
        func singleQuotesThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    argumentsJSON: "{'city': 'SF'}"
                )
            }
        }

        @Test("Non-JSON primitive in arguments throws error")
        func nonJSONPrimitiveThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    argumentsJSON: "not json at all"
                )
            }
        }

        @Test("Empty string arguments throws error")
        func emptyStringArgumentsThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    argumentsJSON: ""
                )
            }
        }

        @Test("Whitespace-only arguments throws error")
        func whitespaceOnlyArgumentsThrowsError() {
            #expect(throws: Error.self) {
                _ = try AIToolCall(
                    id: "call_123",
                    toolName: "get_weather",
                    argumentsJSON: "   "
                )
            }
        }

        @Test("Valid empty object arguments succeeds")
        func validEmptyObjectSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "get_time",
                argumentsJSON: "{}"
            )
            #expect(toolCall.argumentsString == "{}")
        }

        @Test("Valid arguments with nested objects succeeds")
        func validNestedArgumentsSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "complex_tool",
                argumentsJSON: #"{"user": {"name": "John", "age": 30}, "active": true}"#
            )
            #expect(toolCall.toolName == "complex_tool")
        }

        @Test("Valid arguments with array succeeds")
        func validArrayArgumentsSucceeds() throws {
            let toolCall = try AIToolCall(
                id: "call_123",
                toolName: "batch_tool",
                argumentsJSON: #"{"items": [1, 2, 3], "names": ["a", "b"]}"#
            )
            #expect(toolCall.toolName == "batch_tool")
        }
    }

    // MARK: - Error Category Tests

    @Suite("Error Category")
    struct ErrorCategoryTests {

        @Test("invalidToolName error is in input category")
        func invalidToolNameIsInputCategory() {
            let error = AIError.invalidToolName(name: "bad name", reason: "Contains spaces")
            #expect(error.category == .input)
        }

        @Test("invalidToolName error has localized description")
        func invalidToolNameHasLocalizedDescription() {
            let error = AIError.invalidToolName(name: "bad@name", reason: "Invalid characters")
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.localizedStandardContains("bad@name") == true)
        }

        @Test("invalidToolName error has recovery suggestion")
        func invalidToolNameHasRecoverySuggestion() {
            let error = AIError.invalidToolName(name: "bad name", reason: "Contains spaces")
            let suggestion = error.recoverySuggestion
            #expect(suggestion != nil)
            #expect(suggestion?.localizedStandardContains("alphanumeric") == true)
        }

        @Test("invalidToolName error is not retryable")
        func invalidToolNameIsNotRetryable() {
            let error = AIError.invalidToolName(name: "bad", reason: "reason")
            #expect(!error.isRetryable)
        }
    }
}
