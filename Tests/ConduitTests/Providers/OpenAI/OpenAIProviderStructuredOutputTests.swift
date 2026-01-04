// OpenAIProviderStructuredOutputTests.swift
// Conduit Tests
//
// Tests for OpenRouter/OpenAI structured output support.

import Foundation
import Testing
@testable import Conduit

// MARK: - Test Suite

@Suite("OpenAI Provider Structured Output Tests")
struct OpenAIProviderStructuredOutputTests {

    // MARK: - ResponseFormat Type Tests

    @Suite("ResponseFormat Type")
    struct ResponseFormatTypeTests {

        @Test("ResponseFormat has text case")
        func textCase() {
            let format = ResponseFormat.text
            #expect(format == .text)
        }

        @Test("ResponseFormat has jsonObject case")
        func jsonObjectCase() {
            let format = ResponseFormat.jsonObject
            #expect(format == .jsonObject)
        }

        @Test("ResponseFormat has jsonSchema case with schema and name")
        func jsonSchemaCase() {
            let schema = Schema.object(
                name: "TestSchema",
                description: nil,
                properties: [
                    "name": .init(schema: .string(constraints: []), description: nil)
                ]
            )

            let format = ResponseFormat.jsonSchema(name: "TestSchema", schema: schema)

            if case .jsonSchema(let name, let extractedSchema) = format {
                #expect(name == "TestSchema")
                #expect(extractedSchema == schema)
            } else {
                Issue.record("Expected jsonSchema case")
            }
        }

        @Test("ResponseFormat conforms to Sendable")
        func sendableConformance() {
            let format: ResponseFormat = .jsonObject
            let _: any Sendable = format
        }

        @Test("ResponseFormat conforms to Hashable")
        func hashableConformance() {
            let format1 = ResponseFormat.text
            let format2 = ResponseFormat.jsonObject

            var set = Set<ResponseFormat>()
            set.insert(format1)
            set.insert(format2)

            #expect(set.count == 2)
        }

        @Test("ResponseFormat conforms to Codable")
        func codableConformance() throws {
            let original = ResponseFormat.jsonObject
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ResponseFormat.self, from: data)

            #expect(decoded == original)
        }

        @Test("jsonSchema ResponseFormat round-trips through Codable")
        func jsonSchemaRoundTrip() throws {
            let schema = Schema.object(
                name: "User",
                description: "A user object",
                properties: [
                    "id": .init(schema: .integer(constraints: []), description: "User ID"),
                    "name": .init(schema: .string(constraints: []), description: "User name")
                ]
            )

            let original = ResponseFormat.jsonSchema(name: "User", schema: schema)
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ResponseFormat.self, from: data)

            #expect(decoded == original)
        }
    }

    // MARK: - GenerateConfig Integration Tests

    @Suite("GenerateConfig Integration")
    struct GenerateConfigIntegrationTests {

        @Test("GenerateConfig has responseFormat property")
        func responseFormatProperty() {
            let config = GenerateConfig.default
            #expect(config.responseFormat == nil)
        }

        @Test("GenerateConfig fluent API for setting responseFormat")
        func fluentAPIResponseFormat() {
            let config = GenerateConfig.default
                .responseFormat(.jsonObject)

            #expect(config.responseFormat == .jsonObject)
        }

        @Test("GenerateConfig fluent API preserves other settings")
        func fluentAPIPreservesSettings() {
            let config = GenerateConfig.default
                .temperature(0.5)
                .maxTokens(500)
                .responseFormat(.jsonObject)

            #expect(config.temperature == 0.5)
            #expect(config.maxTokens == 500)
            #expect(config.responseFormat == .jsonObject)
        }

        @Test("GenerateConfig with jsonSchema responseFormat")
        func jsonSchemaResponseFormat() {
            let schema = Schema.object(
                name: "MovieReview",
                description: nil,
                properties: [
                    "rating": .init(
                        schema: .integer(constraints: []),
                        description: "Rating from 1-10"
                    ),
                    "summary": .init(
                        schema: .string(constraints: []),
                        description: "Brief summary"
                    )
                ]
            )

            let config = GenerateConfig.default
                .responseFormat(.jsonSchema(name: "MovieReview", schema: schema))

            if case .jsonSchema(let name, _) = config.responseFormat {
                #expect(name == "MovieReview")
            } else {
                Issue.record("Expected jsonSchema response format")
            }
        }

        @Test("GenerateConfig responseFormat is included in Codable")
        func responseFormatCodable() throws {
            let config = GenerateConfig.default
                .responseFormat(.jsonObject)

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(config)
            let decoded = try decoder.decode(GenerateConfig.self, from: data)

            #expect(decoded.responseFormat == .jsonObject)
        }

        @Test("GenerateConfig responseFormat nil is preserved in Codable")
        func responseFormatNilCodable() throws {
            let config = GenerateConfig.default

            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(config)
            let decoded = try decoder.decode(GenerateConfig.self, from: data)

            #expect(decoded.responseFormat == nil)
        }
    }

    // MARK: - Compatibility Tests

    @Suite("Compatibility")
    struct CompatibilityTests {

        @Test("responseFormat preserved in config copy")
        func responseFormatPreservedInCopy() {
            let config = GenerateConfig.default
                .responseFormat(.jsonObject)
                .temperature(0.5)

            #expect(config.responseFormat == .jsonObject)
            #expect(config.temperature == 0.5)

            let modified = config.maxTokens(500)

            #expect(modified.responseFormat == .jsonObject)
            #expect(modified.temperature == 0.5)
            #expect(modified.maxTokens == 500)
        }
    }
}
