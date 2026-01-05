// GuideMacroTests.swift
// ConduitMacrosTests
//
// Tests for the @Guide marker macro.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import ConduitMacros

// MARK: - GuideMacroTests

@Suite("Guide Macro Tests")
struct GuideMacroTests {

    // MARK: - Test Macros Registry

    private let testMacros: [String: Macro.Type] = [
        "Guide": GuideMacro.self,
    ]

    // MARK: - No Code Generation Tests

    @Test("Guide macro with description produces no peer declarations")
    func testGuideProducesNoCode() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("A description")
                let value: Int
            }
            """,
            expandedSource: """
            struct Example {
                let value: Int
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro with description and constraint produces no peer declarations")
    func testGuideWithConstraint() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("Rating from 1 to 10", .range(1...10))
                let rating: Int
            }
            """,
            expandedSource: """
            struct Example {
                let rating: Int
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro with multiple constraints produces no peer declarations")
    func testGuideMultipleConstraints() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("Summary text", .minLength(10), .maxLength(500))
                let summary: String
            }
            """,
            expandedSource: """
            struct Example {
                let summary: String
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro with anyOf constraint produces no peer declarations")
    func testGuideWithAnyOfConstraint() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("Difficulty level", .anyOf(["easy", "medium", "hard"]))
                let difficulty: String
            }
            """,
            expandedSource: """
            struct Example {
                let difficulty: String
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro on multiple properties produces no peer declarations")
    func testGuideOnMultipleProperties() {
        assertMacroExpansion(
            """
            struct Recipe {
                @Guide("The recipe title")
                let title: String

                @Guide("Cooking time in minutes", .range(1...180))
                let cookingTime: Int

                @Guide("Difficulty level", .anyOf(["easy", "medium", "hard"]))
                let difficulty: String
            }
            """,
            expandedSource: """
            struct Recipe {
                let title: String
                let cookingTime: Int
                let difficulty: String
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro on optional property produces no peer declarations")
    func testGuideOnOptionalProperty() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("An optional note")
                let note: String?
            }
            """,
            expandedSource: """
            struct Example {
                let note: String?
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }

    @Test("Guide macro on array property produces no peer declarations")
    func testGuideOnArrayProperty() {
        assertMacroExpansion(
            """
            struct Example {
                @Guide("List of tags", .minItems(1), .maxItems(10))
                let tags: [String]
            }
            """,
            expandedSource: """
            struct Example {
                let tags: [String]
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4)
        )
    }
}
