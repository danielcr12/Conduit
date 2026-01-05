// StructuredContentTests.swift
// ConduitTests

import Foundation
import Testing
@testable import Conduit

/// Tests for StructuredContent - JSON-like intermediate representation
@Suite("StructuredContent")
struct StructuredContentTests {

    // MARK: - JSON Parsing Tests

    @Suite("JSON Parsing")
    struct JSONParsingTests {

        @Test("Parse valid JSON string")
        func parseValidJSONString() throws {
            let json = """
            {"name": "Swift", "version": 6.0, "modern": true}
            """

            let content = try StructuredContent(json: json)

            let obj = try content.object
            #expect(try obj["name"]?.string == "Swift")
            #expect(try obj["version"]?.double == 6.0)
            #expect(try obj["modern"]?.bool == true)
        }

        @Test("Parse JSON with nested objects")
        func parseNestedObjects() throws {
            let json = """
            {"person": {"name": "Alice", "age": 30}}
            """

            let content = try StructuredContent(json: json)

            let obj = try content.object
            let person = try obj["person"]?.object
            #expect(try person?["name"]?.string == "Alice")
            #expect(try person?["age"]?.int == 30)
        }

        @Test("Parse JSON with arrays")
        func parseArrays() throws {
            let json = """
            {"numbers": [1, 2, 3, 4, 5]}
            """

            let content = try StructuredContent(json: json)

            let obj = try content.object
            let numbers = try obj["numbers"]?.array
            #expect(numbers?.count == 5)
            #expect(try numbers?[0].int == 1)
            #expect(try numbers?[4].int == 5)
        }

        @Test("Parse JSON with null values")
        func parseNullValues() throws {
            let json = """
            {"value": null}
            """

            let content = try StructuredContent(json: json)

            let obj = try content.object
            #expect(obj["value"]?.isNull == true)
        }

        @Test("Parse JSON primitive string")
        func parsePrimitiveString() throws {
            let json = "\"hello world\""

            let content = try StructuredContent(json: json)

            #expect(try content.string == "hello world")
        }

        @Test("Parse JSON primitive number")
        func parsePrimitiveNumber() throws {
            let json = "42"

            let content = try StructuredContent(json: json)

            #expect(try content.int == 42)
        }

        @Test("Parse JSON primitive boolean true")
        func parsePrimitiveBoolTrue() throws {
            let json = "true"

            let content = try StructuredContent(json: json)

            #expect(try content.bool == true)
        }

        @Test("Parse JSON primitive boolean false")
        func parsePrimitiveBoolFalse() throws {
            let json = "false"

            let content = try StructuredContent(json: json)

            #expect(try content.bool == false)
        }

        @Test("Parse JSON primitive null")
        func parsePrimitiveNull() throws {
            let json = "null"

            let content = try StructuredContent(json: json)

            #expect(content.isNull == true)
        }

        @Test("Parse JSON from Data")
        func parseFromData() throws {
            let json = """
            {"key": "value"}
            """
            let data = json.data(using: .utf8)!

            let content = try StructuredContent(data: data)

            let obj = try content.object
            #expect(try obj["key"]?.string == "value")
        }

        @Test("Invalid JSON throws error")
        func invalidJSONThrows() {
            let invalidJSON = "{ invalid json }"

            #expect(throws: StructuredContentError.self) {
                _ = try StructuredContent(json: invalidJSON)
            }
        }

        @Test("Empty string throws error")
        func emptyStringThrows() {
            let emptyJSON = ""

            #expect(throws: StructuredContentError.self) {
                _ = try StructuredContent(json: emptyJSON)
            }
        }

        @Test("Malformed JSON throws invalidJSON error")
        func malformedJSONError() {
            do {
                _ = try StructuredContent(json: "{ not valid }")
                Issue.record("Expected error to be thrown")
            } catch let error as StructuredContentError {
                if case .invalidJSON = error {
                    // Expected
                } else {
                    Issue.record("Expected invalidJSON error, got: \(error)")
                }
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - Type Accessor Tests

    @Suite("Type Accessors")
    struct TypeAccessorTests {

        @Test("String accessor returns value")
        func stringAccessor() throws {
            let content = StructuredContent.string("hello")

            #expect(try content.string == "hello")
        }

        @Test("Int accessor returns whole number")
        func intAccessorWholeNumber() throws {
            let content = StructuredContent.number(42.0)

            #expect(try content.int == 42)
        }

        @Test("Int accessor works with negative numbers")
        func intAccessorNegative() throws {
            let content = StructuredContent.number(-100.0)

            #expect(try content.int == -100)
        }

        @Test("Int accessor with large number")
        func intAccessorLargeNumber() throws {
            let content = StructuredContent.number(1_000_000.0)

            #expect(try content.int == 1_000_000)
        }

        @Test("Double accessor returns value")
        func doubleAccessor() throws {
            let content = StructuredContent.number(3.14159)

            #expect(try content.double == 3.14159)
        }

        @Test("Bool accessor returns true")
        func boolAccessorTrue() throws {
            let content = StructuredContent.bool(true)

            #expect(try content.bool == true)
        }

        @Test("Bool accessor returns false")
        func boolAccessorFalse() throws {
            let content = StructuredContent.bool(false)

            #expect(try content.bool == false)
        }

        @Test("Array accessor returns values")
        func arrayAccessor() throws {
            let content = StructuredContent.array([
                .string("a"),
                .string("b"),
                .string("c")
            ])

            let arr = try content.array
            #expect(arr.count == 3)
            #expect(try arr[0].string == "a")
        }

        @Test("Object accessor returns dictionary")
        func objectAccessor() throws {
            let content = StructuredContent.object([
                "key1": .string("value1"),
                "key2": .number(42)
            ])

            let obj = try content.object
            #expect(obj.count == 2)
            #expect(try obj["key1"]?.string == "value1")
            #expect(try obj["key2"]?.int == 42)
        }

        @Test("isNull returns true for null")
        func isNullTrue() {
            let content = StructuredContent.null

            #expect(content.isNull == true)
        }

        @Test("isNull returns false for non-null")
        func isNullFalse() {
            let content = StructuredContent.string("not null")

            #expect(content.isNull == false)
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling")
    struct ErrorHandlingTests {

        @Test("Type mismatch: string on number")
        func typeMismatchStringOnNumber() {
            let content = StructuredContent.number(42)

            #expect(throws: StructuredContentError.self) {
                _ = try content.string
            }
        }

        @Test("Type mismatch: int on string")
        func typeMismatchIntOnString() {
            let content = StructuredContent.string("not a number")

            #expect(throws: StructuredContentError.self) {
                _ = try content.int
            }
        }

        @Test("Type mismatch: bool on string")
        func typeMismatchBoolOnString() {
            let content = StructuredContent.string("true")

            #expect(throws: StructuredContentError.self) {
                _ = try content.bool
            }
        }

        @Test("Type mismatch: array on object")
        func typeMismatchArrayOnObject() {
            let content = StructuredContent.object(["key": .string("value")])

            #expect(throws: StructuredContentError.self) {
                _ = try content.array
            }
        }

        @Test("Type mismatch: object on array")
        func typeMismatchObjectOnArray() {
            let content = StructuredContent.array([.string("value")])

            #expect(throws: StructuredContentError.self) {
                _ = try content.object
            }
        }

        @Test("Invalid integer value: fractional")
        func invalidIntegerFractional() {
            let content = StructuredContent.number(3.14)

            do {
                _ = try content.int
                Issue.record("Expected error to be thrown")
            } catch let error as StructuredContentError {
                if case .invalidIntegerValue(let value) = error {
                    #expect(value == 3.14)
                } else {
                    Issue.record("Expected invalidIntegerValue error")
                }
            } catch {
                Issue.record("Unexpected error type")
            }
        }

        @Test("Invalid integer value: infinity")
        func invalidIntegerInfinity() {
            let content = StructuredContent.number(.infinity)

            #expect(throws: StructuredContentError.self) {
                _ = try content.int
            }
        }

        @Test("Invalid integer value: NaN")
        func invalidIntegerNaN() {
            let content = StructuredContent.number(.nan)

            #expect(throws: StructuredContentError.self) {
                _ = try content.int
            }
        }

        @Test("Missing key throws error")
        func missingKeyError() throws {
            let content = StructuredContent.object(["existing": .string("value")])

            #expect(throws: StructuredContentError.self) {
                _ = try content.requiredValue(forKey: "missing")
            }
        }

        @Test("Value for key returns nil for missing")
        func valueForKeyNilForMissing() throws {
            let content = StructuredContent.object(["existing": .string("value")])

            let value = try content.value(forKey: "missing")
            #expect(value == nil)
        }

        @Test("Value for key returns value for existing")
        func valueForKeyReturnsValue() throws {
            let content = StructuredContent.object(["key": .string("value")])

            let value = try content.value(forKey: "key")
            #expect(try value?.string == "value")
        }

        @Test("Error descriptions are meaningful")
        func errorDescriptions() {
            let typeMismatch = StructuredContentError.typeMismatch(expected: "string", actual: "number")
            #expect(typeMismatch.errorDescription?.contains("string") == true)
            #expect(typeMismatch.errorDescription?.contains("number") == true)

            let invalidJSON = StructuredContentError.invalidJSON("test error")
            #expect(invalidJSON.errorDescription?.contains("Invalid JSON") == true)

            let invalidInt = StructuredContentError.invalidIntegerValue(3.14)
            #expect(invalidInt.errorDescription?.contains("3.14") == true)

            let missingKey = StructuredContentError.missingKey("testKey")
            #expect(missingKey.errorDescription?.contains("testKey") == true)
        }

        @Test("StructuredContentError is Equatable")
        func errorEquatable() {
            let error1 = StructuredContentError.typeMismatch(expected: "string", actual: "number")
            let error2 = StructuredContentError.typeMismatch(expected: "string", actual: "number")
            let error3 = StructuredContentError.typeMismatch(expected: "int", actual: "number")

            #expect(error1 == error2)
            #expect(error1 != error3)
        }
    }

    // MARK: - Codable Round-Trip Tests

    @Suite("Codable")
    struct CodableTests {

        @Test("Null round-trip")
        func nullRoundTrip() throws {
            let original = StructuredContent.null
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            #expect(decoded.isNull == true)
        }

        @Test("Bool true round-trip")
        func boolTrueRoundTrip() throws {
            let original = StructuredContent.bool(true)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            #expect(try decoded.bool == true)
        }

        @Test("Bool false round-trip")
        func boolFalseRoundTrip() throws {
            let original = StructuredContent.bool(false)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            #expect(try decoded.bool == false)
        }

        @Test("Number round-trip")
        func numberRoundTrip() throws {
            let original = StructuredContent.number(42.5)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            #expect(try decoded.double == 42.5)
        }

        @Test("String round-trip")
        func stringRoundTrip() throws {
            let original = StructuredContent.string("hello world")
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            #expect(try decoded.string == "hello world")
        }

        @Test("Array round-trip")
        func arrayRoundTrip() throws {
            let original = StructuredContent.array([
                .string("a"),
                .number(1),
                .bool(true)
            ])
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            let arr = try decoded.array
            #expect(arr.count == 3)
            #expect(try arr[0].string == "a")
            #expect(try arr[1].int == 1)
            #expect(try arr[2].bool == true)
        }

        @Test("Object round-trip")
        func objectRoundTrip() throws {
            let original = StructuredContent.object([
                "name": .string("test"),
                "count": .number(42)
            ])
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            let obj = try decoded.object
            #expect(try obj["name"]?.string == "test")
            #expect(try obj["count"]?.int == 42)
        }

        @Test("Complex nested structure round-trip")
        func complexStructureRoundTrip() throws {
            let original = StructuredContent.object([
                "users": .array([
                    .object([
                        "name": .string("Alice"),
                        "age": .number(30),
                        "active": .bool(true)
                    ]),
                    .object([
                        "name": .string("Bob"),
                        "age": .number(25),
                        "active": .bool(false)
                    ])
                ]),
                "count": .number(2),
                "metadata": .null
            ])

            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(StructuredContent.self, from: encoded)

            let users = try decoded.object["users"]?.array
            #expect(users?.count == 2)
            #expect(try users?[0].object["name"]?.string == "Alice")
            #expect(try users?[1].object["age"]?.int == 25)
        }
    }

    // MARK: - Literal Expressibility Tests

    @Suite("Literal Expressibility")
    struct LiteralExpressibilityTests {

        @Test("Nil literal")
        func nilLiteral() {
            let content: StructuredContent = nil

            #expect(content.isNull == true)
        }

        @Test("Boolean literal true")
        func boolLiteralTrue() throws {
            let content: StructuredContent = true

            #expect(try content.bool == true)
        }

        @Test("Boolean literal false")
        func boolLiteralFalse() throws {
            let content: StructuredContent = false

            #expect(try content.bool == false)
        }

        @Test("Integer literal")
        func integerLiteral() throws {
            let content: StructuredContent = 42

            #expect(try content.int == 42)
        }

        @Test("Float literal")
        func floatLiteral() throws {
            let content: StructuredContent = 3.14

            #expect(try content.double == 3.14)
        }

        @Test("String literal")
        func stringLiteral() throws {
            let content: StructuredContent = "hello"

            #expect(try content.string == "hello")
        }

        @Test("Array literal")
        func arrayLiteral() throws {
            let content: StructuredContent = [1, 2, 3]

            let arr = try content.array
            #expect(arr.count == 3)
            #expect(try arr[0].int == 1)
        }

        @Test("Dictionary literal")
        func dictionaryLiteral() throws {
            let content: StructuredContent = ["key": "value", "count": 42]

            let obj = try content.object
            #expect(try obj["key"]?.string == "value")
            #expect(try obj["count"]?.int == 42)
        }

        @Test("Nested literals")
        func nestedLiterals() throws {
            let content: StructuredContent = [
                "name": "test",
                "items": [1, 2, 3],
                "active": true
            ]

            let obj = try content.object
            #expect(try obj["name"]?.string == "test")
            #expect(try obj["active"]?.bool == true)
        }
    }

    // MARK: - Serialization Tests

    @Suite("Serialization")
    struct SerializationTests {

        @Test("toJSON returns valid JSON string")
        func toJSONValidString() throws {
            let content = StructuredContent.object([
                "name": .string("Swift"),
                "version": .number(6)
            ])

            let json = try content.toJSON()

            #expect(json.contains("\"name\""))
            #expect(json.contains("\"Swift\""))
            #expect(json.contains("\"version\""))
        }

        @Test("toData returns valid UTF-8 data")
        func toDataValidUTF8() throws {
            let content = StructuredContent.string("hello")

            let data = try content.toData()
            let string = String(data: data, encoding: .utf8)

            #expect(string == "\"hello\"")
        }

        @Test("Whole numbers serialize as integers")
        func wholeNumbersAsIntegers() throws {
            let content = StructuredContent.number(42.0)

            let json = try content.toJSON()

            #expect(json == "42")
        }

        @Test("Fractional numbers serialize with decimals")
        func fractionalNumbersWithDecimals() throws {
            let content = StructuredContent.number(3.14)

            let json = try content.toJSON()

            #expect(json.contains("3.14"))
        }

        // MARK: - Primitive Serialization Tests

        @Test("Serialize null primitive")
        func serializeNullPrimitive() throws {
            let content = StructuredContent.null
            let json = try content.toJSON()
            #expect(json == "null")
        }

        @Test("Serialize bool true primitive")
        func serializeBoolTruePrimitive() throws {
            let content = StructuredContent.bool(true)
            let json = try content.toJSON()
            #expect(json == "true")
        }

        @Test("Serialize bool false primitive")
        func serializeBoolFalsePrimitive() throws {
            let content = StructuredContent.bool(false)
            let json = try content.toJSON()
            #expect(json == "false")
        }

        @Test("Serialize number primitive")
        func serializeNumberPrimitive() throws {
            let content = StructuredContent.number(42)
            let json = try content.toJSON()
            #expect(json == "42")
        }

        @Test("Serialize negative number primitive")
        func serializeNegativeNumberPrimitive() throws {
            let content = StructuredContent.number(-100.5)
            let json = try content.toJSON()
            #expect(json == "-100.5")
        }

        @Test("Serialize zero")
        func serializeZero() throws {
            let content = StructuredContent.number(0)
            let json = try content.toJSON()
            #expect(json == "0")
        }

        @Test("Serialize string primitive")
        func serializeStringPrimitive() throws {
            let content = StructuredContent.string("hello")
            let json = try content.toJSON()
            #expect(json == "\"hello\"")
        }

        @Test("Serialize empty string")
        func serializeEmptyString() throws {
            let content = StructuredContent.string("")
            let json = try content.toJSON()
            #expect(json == "\"\"")
        }

        @Test("NaN throws error on serialization")
        func nanThrowsError() {
            let content = StructuredContent.number(.nan)
            #expect(throws: StructuredContentError.self) {
                _ = try content.toJSON()
            }
        }

        @Test("Positive infinity throws error on serialization")
        func positiveInfinityThrowsError() {
            let content = StructuredContent.number(.infinity)
            #expect(throws: StructuredContentError.self) {
                _ = try content.toJSON()
            }
        }

        @Test("Negative infinity throws error on serialization")
        func negativeInfinityThrowsError() {
            let content = StructuredContent.number(-.infinity)
            #expect(throws: StructuredContentError.self) {
                _ = try content.toJSON()
            }
        }

        // MARK: - String Escaping Tests

        @Test("Serialize string with backslash")
        func serializeStringWithBackslash() throws {
            let content = StructuredContent.string("path\\to\\file")
            let json = try content.toJSON()
            #expect(json == "\"path\\\\to\\\\file\"")
        }

        @Test("Serialize string with quotes")
        func serializeStringWithQuotes() throws {
            let content = StructuredContent.string("He said \"hello\"")
            let json = try content.toJSON()
            #expect(json == "\"He said \\\"hello\\\"\"")
        }

        @Test("Serialize string with newline")
        func serializeStringWithNewline() throws {
            let content = StructuredContent.string("line1\nline2")
            let json = try content.toJSON()
            #expect(json == "\"line1\\nline2\"")
        }

        @Test("Serialize string with carriage return")
        func serializeStringWithCarriageReturn() throws {
            let content = StructuredContent.string("before\rafter")
            let json = try content.toJSON()
            #expect(json == "\"before\\rafter\"")
        }

        @Test("Serialize string with tab")
        func serializeStringWithTab() throws {
            let content = StructuredContent.string("col1\tcol2")
            let json = try content.toJSON()
            #expect(json == "\"col1\\tcol2\"")
        }

        @Test("Serialize string with control characters")
        func serializeStringWithControlCharacters() throws {
            // Test various control characters (U+0000 to U+001F)
            let content = StructuredContent.string("test\u{0008}backspace")
            let json = try content.toJSON()
            // JSONSerialization should escape control characters
            #expect(json.contains("\\"))
        }

        @Test("Serialize string with unicode characters")
        func serializeStringWithUnicode() throws {
            let content = StructuredContent.string("Hello 🌍 World")
            let json = try content.toJSON()
            // Should handle unicode properly
            #expect(json.contains("Hello"))
            #expect(json.contains("World"))
        }

        @Test("Serialize string with line separator")
        func serializeStringWithLineSeparator() throws {
            let content = StructuredContent.string("line\u{2028}separator")
            let json = try content.toJSON()
            // JSONSerialization should escape U+2028
            #expect(json.contains("line"))
            #expect(json.contains("separator"))
        }

        @Test("Serialize string with paragraph separator")
        func serializeStringWithParagraphSeparator() throws {
            let content = StructuredContent.string("para\u{2029}separator")
            let json = try content.toJSON()
            // JSONSerialization should escape U+2029
            #expect(json.contains("para"))
            #expect(json.contains("separator"))
        }

        @Test("Serialize complex string with multiple special characters")
        func serializeComplexString() throws {
            let content = StructuredContent.string("Line 1\nLine 2\t\"quoted\"\r\nBackslash: \\")
            let json = try content.toJSON()
            // Verify it's valid JSON by parsing it back
            let reparsed = try StructuredContent(json: json)
            #expect(try reparsed.string == "Line 1\nLine 2\t\"quoted\"\r\nBackslash: \\")
        }

        // MARK: - Round-trip Serialization Tests

        @Test("Primitive null round-trip via toJSON")
        func primitiveNullRoundTrip() throws {
            let original = StructuredContent.null
            let json = try original.toJSON()
            let parsed = try StructuredContent(json: json)
            #expect(parsed.isNull == true)
        }

        @Test("Primitive bool round-trip via toJSON")
        func primitiveBoolRoundTrip() throws {
            let original = StructuredContent.bool(true)
            let json = try original.toJSON()
            let parsed = try StructuredContent(json: json)
            #expect(try parsed.bool == true)
        }

        @Test("Primitive number round-trip via toJSON")
        func primitiveNumberRoundTrip() throws {
            let original = StructuredContent.number(42.5)
            let json = try original.toJSON()
            let parsed = try StructuredContent(json: json)
            #expect(try parsed.double == 42.5)
        }

        @Test("Primitive string round-trip via toJSON")
        func primitiveStringRoundTrip() throws {
            let original = StructuredContent.string("test\nwith\tspecial\"chars\\")
            let json = try original.toJSON()
            let parsed = try StructuredContent(json: json)
            #expect(try parsed.string == "test\nwith\tspecial\"chars\\")
        }

        // MARK: - toData() Optimization Tests

        @Test("toData for array avoids double conversion")
        func toDataArrayOptimization() throws {
            let content = StructuredContent.array([.number(1), .number(2), .number(3)])
            let data = try content.toData()
            // Should be able to parse it back
            let parsed = try StructuredContent(data: data)
            #expect(try parsed.array.count == 3)
        }

        @Test("toData for object avoids double conversion")
        func toDataObjectOptimization() throws {
            let content = StructuredContent.object(["key": .string("value")])
            let data = try content.toData()
            // Should be able to parse it back
            let parsed = try StructuredContent(data: data)
            #expect(try parsed.object["key"]?.string == "value")
        }

        @Test("toData for primitive null")
        func toDataPrimitiveNull() throws {
            let content = StructuredContent.null
            let data = try content.toData()
            let parsed = try StructuredContent(data: data)
            #expect(parsed.isNull == true)
        }

        @Test("toData for primitive string")
        func toDataPrimitiveString() throws {
            let content = StructuredContent.string("hello")
            let data = try content.toData()
            let parsed = try StructuredContent(data: data)
            #expect(try parsed.string == "hello")
        }

        @Test("toData rejects NaN")
        func toDataRejectsNaN() {
            let content = StructuredContent.number(.nan)
            #expect(throws: StructuredContentError.self) {
                _ = try content.toData()
            }
        }

        @Test("toData rejects infinity")
        func toDataRejectsInfinity() {
            let content = StructuredContent.number(.infinity)
            #expect(throws: StructuredContentError.self) {
                _ = try content.toData()
            }
        }

        // MARK: - Regression Tests

        @Test("Regression: Primitive types don't crash toJSON")
        func regressionPrimitiveTypesSerialization() throws {
            // This is a regression test for the fix where toJSON() would crash
            // when serializing primitive types because NSJSONSerialization requires
            // top-level objects to be arrays or dictionaries.

            // Test all primitive types serialize without crashing
            let nullContent = StructuredContent.null
            let nullJSON = try nullContent.toJSON()
            #expect(nullJSON == "null")

            let boolContent = StructuredContent.bool(true)
            let boolJSON = try boolContent.toJSON()
            #expect(boolJSON == "true")

            let numberContent = StructuredContent.number(42)
            let numberJSON = try numberContent.toJSON()
            #expect(numberJSON == "42")

            let stringContent = StructuredContent.string("test")
            let stringJSON = try stringContent.toJSON()
            #expect(stringJSON == "\"test\"")

            // Verify they can all be parsed back
            let parsedNull = try StructuredContent(json: nullJSON)
            #expect(parsedNull.isNull == true)

            let parsedBool = try StructuredContent(json: boolJSON)
            #expect(try parsedBool.bool == true)

            let parsedNumber = try StructuredContent(json: numberJSON)
            #expect(try parsedNumber.int == 42)

            let parsedString = try StructuredContent(json: stringJSON)
            #expect(try parsedString.string == "test")
        }

        @Test("Regression: Primitive types don't crash toData")
        func regressionPrimitiveTypesToData() throws {
            // This is a regression test for the fix where toData() would crash
            // when serializing primitive types.

            let nullContent = StructuredContent.null
            let nullData = try nullContent.toData()
            let parsedNull = try StructuredContent(data: nullData)
            #expect(parsedNull.isNull == true)

            let boolContent = StructuredContent.bool(false)
            let boolData = try boolContent.toData()
            let parsedBool = try StructuredContent(data: boolData)
            #expect(try parsedBool.bool == false)

            let numberContent = StructuredContent.number(123.45)
            let numberData = try numberContent.toData()
            let parsedNumber = try StructuredContent(data: numberData)
            #expect(try parsedNumber.double == 123.45)

            let stringContent = StructuredContent.string("hello world")
            let stringData = try stringContent.toData()
            let parsedString = try StructuredContent(data: stringData)
            #expect(try parsedString.string == "hello world")
        }
    }

    // MARK: - Equality and Hashing Tests

    @Suite("Equality and Hashing")
    struct EqualityHashingTests {

        @Test("Equal contents are equal")
        func equalContentsEqual() {
            let content1 = StructuredContent.string("test")
            let content2 = StructuredContent.string("test")

            #expect(content1 == content2)
        }

        @Test("Different contents are not equal")
        func differentContentsNotEqual() {
            let content1 = StructuredContent.string("test1")
            let content2 = StructuredContent.string("test2")

            #expect(content1 != content2)
        }

        @Test("Different types are not equal")
        func differentTypesNotEqual() {
            let content1 = StructuredContent.string("42")
            let content2 = StructuredContent.number(42)

            #expect(content1 != content2)
        }

        @Test("Contents are Hashable")
        func contentsHashable() {
            let content1 = StructuredContent.string("a")
            let content2 = StructuredContent.string("b")
            let content3 = StructuredContent.string("a")

            var set: Set<StructuredContent> = []
            set.insert(content1)
            set.insert(content2)
            set.insert(content3)

            #expect(set.count == 2)
        }

        @Test("Complex objects are Hashable")
        func complexObjectsHashable() {
            let content1 = StructuredContent.object([
                "name": .string("test"),
                "count": .number(42)
            ])
            let content2 = StructuredContent.object([
                "name": .string("test"),
                "count": .number(42)
            ])

            #expect(content1 == content2)
            #expect(content1.hashValue == content2.hashValue)
        }
    }

    // MARK: - CustomStringConvertible Tests

    @Suite("Description")
    struct DescriptionTests {

        @Test("Description returns JSON for valid content")
        func descriptionReturnsJSON() throws {
            let content = StructuredContent.object(["key": .string("value")])

            let description = content.description

            #expect(description.contains("key"))
            #expect(description.contains("value"))
        }

        @Test("Debug description includes kind")
        func debugDescriptionIncludesKind() {
            let content = StructuredContent.string("test")

            let debugDesc = content.debugDescription

            #expect(debugDesc.contains("StructuredContent"))
            #expect(debugDesc.contains("string"))
        }
    }

    // MARK: - Factory Method Tests

    @Suite("Factory Methods")
    struct FactoryMethodTests {

        @Test("Static null constant")
        func staticNullConstant() {
            let content = StructuredContent.null

            #expect(content.isNull == true)
        }

        @Test("Bool factory method")
        func boolFactoryMethod() throws {
            let content = StructuredContent.bool(true)

            #expect(try content.bool == true)
        }

        @Test("Number factory method with Double")
        func numberFactoryDouble() throws {
            let content = StructuredContent.number(3.14)

            #expect(try content.double == 3.14)
        }

        @Test("Number factory method with Int")
        func numberFactoryInt() throws {
            let content = StructuredContent.number(42)

            #expect(try content.int == 42)
        }

        @Test("String factory method")
        func stringFactoryMethod() throws {
            let content = StructuredContent.string("hello")

            #expect(try content.string == "hello")
        }

        @Test("Array factory method")
        func arrayFactoryMethod() throws {
            let content = StructuredContent.array([.string("a"), .string("b")])

            let arr = try content.array
            #expect(arr.count == 2)
        }

        @Test("Object factory method")
        func objectFactoryMethod() throws {
            let content = StructuredContent.object(["key": .string("value")])

            let obj = try content.object
            #expect(try obj["key"]?.string == "value")
        }

        @Test("Kind initializer")
        func kindInitializer() throws {
            let content = StructuredContent(kind: .string("test"))

            #expect(try content.string == "test")
        }
    }

    // MARK: - Kind Type Name Tests

    @Suite("Kind Type Names")
    struct KindTypeNameTests {

        @Test("All kind type names are correct")
        func allKindTypeNames() {
            #expect(StructuredContent.Kind.null.typeName == "null")
            #expect(StructuredContent.Kind.bool(true).typeName == "bool")
            #expect(StructuredContent.Kind.number(1).typeName == "number")
            #expect(StructuredContent.Kind.string("").typeName == "string")
            #expect(StructuredContent.Kind.array([]).typeName == "array")
            #expect(StructuredContent.Kind.object([:]).typeName == "object")
        }
    }
}
