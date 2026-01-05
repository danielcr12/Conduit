// GenerableMacroTests.swift
// ConduitMacrosTests
//
// Comprehensive tests for the @Generable macro expansion.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import ConduitMacros

// MARK: - Test Macros Registry

private let testMacros: [String: Macro.Type] = [
    "Generable": GenerableMacro.self,
    "Guide": GuideMacro.self,
]

// MARK: - GenerableMacroTests

@Suite("Generable Macro Tests")
struct GenerableMacroTests {

    // MARK: - Simple Struct Expansion

    @Test("Simple struct with single String property expands correctly")
    func testSimpleStructExpansion() {
        assertMacroExpansion(
            """
            @Generable
            struct Simple {
                let name: String
            }
            """,
            expandedSource: """
            struct Simple {
                let name: String

                public static var schema: Schema {
                    .object(
                        name: "Simple",
                        description: nil,
                        properties: [
                            "name": Schema.Property(
                                schema: .string(constraints: []),
                                description: nil,
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var name: String?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = name { dict["name"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.name = try? obj["name"].map { try String.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let nameContent = obj["name"] else { throw StructuredContentError.missingKey("name") }
                    self.name = try String.init(from: nameContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["name"] = name.generableContent
                    return .object(dict)
                }
            }

            extension Simple: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    // MARK: - Multiple Properties

    @Test("Struct with multiple properties of different types expands correctly")
    func testMultipleProperties() {
        assertMacroExpansion(
            """
            @Generable
            struct Person {
                let name: String
                let age: Int
            }
            """,
            expandedSource: """
            struct Person {
                let name: String
                let age: Int

                public static var schema: Schema {
                    .object(
                        name: "Person",
                        description: nil,
                        properties: [
                            "name": Schema.Property(
                                schema: .string(constraints: []),
                                description: nil,
                                isRequired: true
                            ),
                            "age": Schema.Property(
                                schema: .integer(constraints: []),
                                description: nil,
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var name: String?
                    public var age: Int?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = name { dict["name"] = v.generableContent }
                        if let v = age { dict["age"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.name = try? obj["name"].map { try String.init(from: $0) }
                        self.age = try? obj["age"].map { try Int.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let nameContent = obj["name"] else { throw StructuredContentError.missingKey("name") }
                    self.name = try String.init(from: nameContent)
                    guard let ageContent = obj["age"] else { throw StructuredContentError.missingKey("age") }
                    self.age = try Int.init(from: ageContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["name"] = name.generableContent
                    dict["age"] = age.generableContent
                    return .object(dict)
                }
            }

            extension Person: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    // MARK: - Optional Property

    @Test("Struct with optional property expands correctly")
    func testOptionalProperty() {
        assertMacroExpansion(
            """
            @Generable
            struct OptionalExample {
                let nickname: String?
            }
            """,
            expandedSource: """
            struct OptionalExample {
                let nickname: String?

                public static var schema: Schema {
                    .object(
                        name: "OptionalExample",
                        description: nil,
                        properties: [
                            "nickname": Schema.Property(
                                schema: .optional(wrapped: .string(constraints: [])),
                                description: nil,
                                isRequired: false
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var nickname: String?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = nickname { dict["nickname"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.nickname = try? obj["nickname"].map { try String.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    self.nickname = try obj["nickname"].map { try String.init(from: $0) }
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    if let v = nickname { dict["nickname"] = v.generableContent }
                    return .object(dict)
                }
            }

            extension OptionalExample: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    // MARK: - Array Property

    @Test("Struct with array property expands correctly")
    func testArrayProperty() {
        assertMacroExpansion(
            """
            @Generable
            struct ArrayExample {
                let tags: [String]
            }
            """,
            expandedSource: """
            struct ArrayExample {
                let tags: [String]

                public static var schema: Schema {
                    .object(
                        name: "ArrayExample",
                        description: nil,
                        properties: [
                            "tags": Schema.Property(
                                schema: .array(items: .string(constraints: []), constraints: []),
                                description: nil,
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var tags: [String]?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = tags { dict["tags"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.tags = try? obj["tags"].map { try [String].init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let tagsContent = obj["tags"] else { throw StructuredContentError.missingKey("tags") }
                    self.tags = try [String].init(from: tagsContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["tags"] = tags.generableContent
                    return .object(dict)
                }
            }

            extension ArrayExample: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    // MARK: - Guide Macro with Description

    @Test("Struct with @Guide description expands correctly")
    func testGuideWithDescription() {
        assertMacroExpansion(
            """
            @Generable
            struct Recipe {
                @Guide("The recipe title")
                let title: String
            }
            """,
            expandedSource: """
            struct Recipe {
                let title: String

                public static var schema: Schema {
                    .object(
                        name: "Recipe",
                        description: nil,
                        properties: [
                            "title": Schema.Property(
                                schema: .string(constraints: []),
                                description: "The recipe title",
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var title: String?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = title { dict["title"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.title = try? obj["title"].map { try String.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let titleContent = obj["title"] else { throw StructuredContentError.missingKey("title") }
                    self.title = try String.init(from: titleContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["title"] = title.generableContent
                    return .object(dict)
                }
            }

            extension Recipe: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    // MARK: - Diagnostic Tests

    @Test("@Generable on class produces error diagnostic")
    func testNotAStructDiagnostic() {
        assertMacroExpansion(
            """
            @Generable
            class NotAStruct {
                var name: String = ""
            }
            """,
            expandedSource: """
            class NotAStruct {
                var name: String = ""
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Generable can only be applied to structs",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    // MARK: - Additional Type Tests

    @Test("Struct with Bool property expands correctly")
    func testBoolProperty() {
        assertMacroExpansion(
            """
            @Generable
            struct BoolExample {
                let isActive: Bool
            }
            """,
            expandedSource: """
            struct BoolExample {
                let isActive: Bool

                public static var schema: Schema {
                    .object(
                        name: "BoolExample",
                        description: nil,
                        properties: [
                            "isActive": Schema.Property(
                                schema: .boolean(constraints: []),
                                description: nil,
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var isActive: Bool?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = isActive { dict["isActive"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.isActive = try? obj["isActive"].map { try Bool.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let isActiveContent = obj["isActive"] else { throw StructuredContentError.missingKey("isActive") }
                    self.isActive = try Bool.init(from: isActiveContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["isActive"] = isActive.generableContent
                    return .object(dict)
                }
            }

            extension BoolExample: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Struct with Double property expands correctly")
    func testDoubleProperty() {
        assertMacroExpansion(
            """
            @Generable
            struct DoubleExample {
                let price: Double
            }
            """,
            expandedSource: """
            struct DoubleExample {
                let price: Double

                public static var schema: Schema {
                    .object(
                        name: "DoubleExample",
                        description: nil,
                        properties: [
                            "price": Schema.Property(
                                schema: .number(constraints: []),
                                description: nil,
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var price: Double?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = price { dict["price"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.price = try? obj["price"].map { try Double.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let priceContent = obj["price"] else { throw StructuredContentError.missingKey("price") }
                    self.price = try Double.init(from: priceContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["price"] = price.generableContent
                    return .object(dict)
                }
            }

            extension DoubleExample: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Struct with Float property expands correctly")
    func testFloatProperty() {
        assertMacroExpansion(
            """
            @Generable
            struct FloatExample {
                let temperature: Float
            }
            """,
            expandedSource: """
            struct FloatExample {
                let temperature: Float

                public static var schema: Schema {
                    .object(
                        name: "FloatExample",
                        description: nil,
                        properties: [
                            "temperature": Schema.Property(
                                schema: .number(constraints: []),
                                description: nil,
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var temperature: Float?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = temperature { dict["temperature"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.temperature = try? obj["temperature"].map { try Float.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let temperatureContent = obj["temperature"] else { throw StructuredContentError.missingKey("temperature") }
                    self.temperature = try Float.init(from: temperatureContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["temperature"] = temperature.generableContent
                    return .object(dict)
                }
            }

            extension FloatExample: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    // MARK: - Complex Examples

    @Test("Struct with mixed required and optional properties")
    func testMixedProperties() {
        assertMacroExpansion(
            """
            @Generable
            struct MixedExample {
                let required: String
                let optional: Int?
            }
            """,
            expandedSource: """
            struct MixedExample {
                let required: String
                let optional: Int?

                public static var schema: Schema {
                    .object(
                        name: "MixedExample",
                        description: nil,
                        properties: [
                            "required": Schema.Property(
                                schema: .string(constraints: []),
                                description: nil,
                                isRequired: true
                            ),
                            "optional": Schema.Property(
                                schema: .optional(wrapped: .integer(constraints: [])),
                                description: nil,
                                isRequired: false
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var required: String?
                    public var optional: Int?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = required { dict["required"] = v.generableContent }
                        if let v = optional { dict["optional"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.required = try? obj["required"].map { try String.init(from: $0) }
                        self.optional = try? obj["optional"].map { try Int.init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let requiredContent = obj["required"] else { throw StructuredContentError.missingKey("required") }
                    self.required = try String.init(from: requiredContent)
                    self.optional = try obj["optional"].map { try Int.init(from: $0) }
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["required"] = required.generableContent
                    if let v = optional { dict["optional"] = v.generableContent }
                    return .object(dict)
                }
            }

            extension MixedExample: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Struct with array of integers")
    func testArrayOfIntegers() {
        assertMacroExpansion(
            """
            @Generable
            struct IntArrayExample {
                let scores: [Int]
            }
            """,
            expandedSource: """
            struct IntArrayExample {
                let scores: [Int]

                public static var schema: Schema {
                    .object(
                        name: "IntArrayExample",
                        description: nil,
                        properties: [
                            "scores": Schema.Property(
                                schema: .array(items: .integer(constraints: []), constraints: []),
                                description: nil,
                                isRequired: true
                            )
                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {
                    public var scores: [Int]?

                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]
                        if let v = scores { dict["scores"] = v.generableContent }
                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object
                        self.scores = try? obj["scores"].map { try [Int].init(from: $0) }
                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object
                    guard let scoresContent = obj["scores"] else { throw StructuredContentError.missingKey("scores") }
                    self.scores = try [Int].init(from: scoresContent)
                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]
                    dict["scores"] = scores.generableContent
                    return .object(dict)
                }
            }

            extension IntArrayExample: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Empty struct expands correctly")
    func testEmptyStruct() {
        assertMacroExpansion(
            """
            @Generable
            struct EmptyStruct {
            }
            """,
            expandedSource: """
            struct EmptyStruct {

                public static var schema: Schema {
                    .object(
                        name: "EmptyStruct",
                        description: nil,
                        properties: [

                        ]
                    )
                }

                public struct Partial: GenerableContentConvertible, Sendable {


                    public var generableContent: StructuredContent {
                        var dict: [String: StructuredContent] = [:]

                        return .object(dict)
                    }

                    public init(from structuredContent: StructuredContent) throws {
                        let obj = try structuredContent.object

                    }

                    public init() {}
                }

                public init(from structuredContent: StructuredContent) throws {
                    let obj = try structuredContent.object

                }

                public var generableContent: StructuredContent {
                    var dict: [String: StructuredContent] = [:]

                    return .object(dict)
                }
            }

            extension EmptyStruct: Generable {
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }
}
