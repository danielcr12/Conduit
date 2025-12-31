# SwiftAI Enhancement Implementation Plan

## Structured Output, Type Safety, Streaming & SwiftAgents Integration

**Created**: December 27, 2025
**Status**: Planning Complete
**Estimated Duration**: 5-6 weeks

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Phase 1: Core Type System](#phase-1-core-type-system)
4. [Phase 2: Macro System](#phase-2-macro-system)
5. [Phase 3: Streaming & JsonRepair](#phase-3-streaming--jsonrepair)
6. [Phase 4: Tool Protocol](#phase-4-tool-protocol)
7. [Phase 5: SwiftAgents Integration](#phase-5-swiftagents-integration)
8. [File Structure](#file-structure)
9. [Dependencies](#dependencies)
10. [Testing Strategy](#testing-strategy)
11. [Migration Guide](#migration-guide)

---

## Executive Summary

This plan outlines the implementation of four transformative features for SwiftAI:

| Feature | Impact | Complexity |
|---------|--------|------------|
| **@Generable Macro** | Compile-time type safety for LLM responses | High |
| **Streaming Partials** | Progressive typed object updates | Medium |
| **Tool Protocol** | Type-safe function calling | Medium |
| **SwiftAgents Integration** | Agent orchestration layer | Medium |

### Key Benefits

- **Type Safety**: LLM responses become as type-safe as regular Swift code
- **Developer Experience**: Autocomplete for LLM response fields
- **Streaming UX**: UI updates progressively as fields complete
- **Agent Patterns**: ReAct, PlanAndExecute without building from scratch

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Application Layer                              │
│                    (iOS/macOS/Linux Applications)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                        SwiftAgents                               │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │    │
│  │  │ ReActAgent  │  │   Memory    │  │Orchestration│              │    │
│  │  │ PlanExecute │  │   Systems   │  │ Resilience  │              │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │    │
│  │                          │                                       │    │
│  │              ┌───────────┴───────────┐                          │    │
│  │              │   InferenceProvider   │ ◄── Protocol              │    │
│  │              └───────────┬───────────┘                          │    │
│  └──────────────────────────┼──────────────────────────────────────┘    │
│                             │                                            │
│              ┌──────────────▼──────────────┐                            │
│              │  SwiftAIInferenceAdapter    │  ◄── Bridge Layer          │
│              └──────────────┬──────────────┘                            │
│                             │                                            │
├─────────────────────────────┼────────────────────────────────────────────┤
│                             │                                            │
│  ┌──────────────────────────▼──────────────────────────────────────┐    │
│  │                         SwiftAI SDK                              │    │
│  │                                                                  │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐  │    │
│  │  │   @Generable     │  │    Providers     │  │   Tool        │  │    │
│  │  │   Macro System   │  │  Anthropic/OpenAI│  │   Protocol    │  │    │
│  │  │                  │  │  MLX/HuggingFace │  │               │  │    │
│  │  │  ┌────────────┐  │  │                  │  │  ┌─────────┐  │  │    │
│  │  │  │  Schema    │  │  │  ┌────────────┐  │  │  │Arguments│  │  │    │
│  │  │  │  Partial   │  │  │  │ Streaming  │  │  │  │:Generable│ │  │    │
│  │  │  │  Content   │  │  │  │ JsonRepair │  │  │  │         │  │  │    │
│  │  │  └────────────┘  │  │  └────────────┘  │  │  └─────────┘  │  │    │
│  │  └──────────────────┘  └──────────────────┘  └───────────────┘  │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Core Type System

**Duration**: Week 1-2
**Priority**: Critical
**Dependencies**: None

### 1.1 StructuredContent

**File**: `Sources/SwiftAI/Core/Types/StructuredContent.swift`

JSON-like intermediate representation for type-safe LLM responses.

```swift
/// JSON-like data structure for representing LLM structured outputs
public struct StructuredContent: Sendable, Equatable, Hashable {

    /// The kind of structured content
    public enum Kind: Sendable, Equatable, Hashable {
        case null
        case bool(Bool)
        case number(Double)
        case string(String)
        case array([StructuredContent])
        case object([String: StructuredContent])
    }

    public let kind: Kind

    // MARK: - Initializers

    public init(kind: Kind)
    public init(json: String) throws
    public init(data: Data) throws

    // MARK: - Type-Safe Accessors

    public var isNull: Bool { get }
    public var string: String { get throws }
    public var int: Int { get throws }
    public var double: Double { get throws }
    public var bool: Bool { get throws }
    public var array: [StructuredContent] { get throws }
    public var object: [String: StructuredContent] { get throws }

    // MARK: - Serialization

    public func toJSON() throws -> String
    public func toData() throws -> Data
}

// MARK: - Errors

public enum StructuredContentError: Error, LocalizedError {
    case typeMismatch(expected: String, actual: String)
    case invalidJSON(String)
    case invalidIntegerValue(Double)
    case missingKey(String)
}
```

**Implementation Tasks**:
- [ ] Create `Kind` enum with all JSON types
- [ ] Implement JSON parsing via `JSONSerialization`
- [ ] Implement type-safe accessors with proper error handling
- [ ] Add `Codable` conformance for serialization
- [ ] Write unit tests for all type conversions

---

### 1.2 Schema

**File**: `Sources/SwiftAI/Core/Types/Schema.swift`

Describes the structure of Generable types for LLM generation.

```swift
import OrderedCollections

/// Describes the structure and constraints of a Generable type
public enum Schema: Sendable, Equatable {

    // Primitive types
    case string(constraints: [StringConstraint])
    case integer(constraints: [IntConstraint])
    case number(constraints: [DoubleConstraint])
    case boolean(constraints: [BoolConstraint])

    // Composite types
    case array(items: Schema, constraints: [ArrayConstraint])
    case object(name: String, description: String?, properties: OrderedDictionary<String, Property>)
    case optional(wrapped: Schema)

    // Union types (for enums with associated values)
    indirect case anyOf(name: String, description: String?, schemas: [Schema])

    /// A property within an object schema
    public struct Property: Sendable, Equatable {
        public let schema: Schema
        public let description: String?
        public let isRequired: Bool

        public init(schema: Schema, description: String? = nil, isRequired: Bool = true)
    }

    // MARK: - Constraint Application

    /// Returns a new schema with the constraint applied
    public func withConstraint<T>(_ constraint: Constraint<T>) -> Schema

    /// Unwraps optional schemas to get the underlying type
    public var unwrapped: Schema { get }
}

// MARK: - Constraint Types

public typealias StringConstraint = Constraint<String>
public typealias IntConstraint = Constraint<Int>
public typealias DoubleConstraint = Constraint<Double>
public typealias BoolConstraint = Constraint<Bool>
public typealias ArrayConstraint = Constraint<[Any]>
```

**Implementation Tasks**:
- [ ] Add `OrderedCollections` dependency to Package.swift
- [ ] Create `Schema` enum with all cases
- [ ] Implement `Property` struct
- [ ] Add constraint application methods
- [ ] Implement `unwrapped` computed property

---

### 1.3 Constraint

**File**: `Sources/SwiftAI/Core/Types/Constraint.swift`

Type-safe constraints for schema validation.

```swift
/// Type-safe constraint for schema validation
public struct Constraint<Value>: Sendable, Equatable {

    internal enum Kind: Sendable, Equatable {
        // String constraints
        case pattern(String)
        case constant(String)
        case anyOf([String])
        case minLength(Int)
        case maxLength(Int)

        // Numeric constraints
        case minimum(Double)
        case maximum(Double)
        case exclusiveMinimum(Double)
        case exclusiveMaximum(Double)
        case multipleOf(Double)

        // Array constraints
        case minItems(Int)
        case maxItems(Int)
        case uniqueItems

        // Boolean constraints
        case constantBool(Bool)
    }

    internal let kind: Kind
}

// MARK: - String Constraints

extension Constraint where Value == String {
    /// Regex pattern the string must match
    public static func pattern(_ regex: String) -> Constraint<String>

    /// Exact value the string must equal
    public static func constant(_ value: String) -> Constraint<String>

    /// Set of allowed values (enum)
    public static func anyOf(_ values: [String]) -> Constraint<String>

    /// Minimum string length
    public static func minLength(_ length: Int) -> Constraint<String>

    /// Maximum string length
    public static func maxLength(_ length: Int) -> Constraint<String>
}

// MARK: - Integer Constraints

extension Constraint where Value == Int {
    public static func minimum(_ value: Int) -> Constraint<Int>
    public static func maximum(_ value: Int) -> Constraint<Int>
    public static func range(_ range: ClosedRange<Int>) -> Constraint<Int>
    public static func multipleOf(_ value: Int) -> Constraint<Int>
}

// MARK: - Double Constraints

extension Constraint where Value == Double {
    public static func minimum(_ value: Double) -> Constraint<Double>
    public static func maximum(_ value: Double) -> Constraint<Double>
    public static func range(_ range: ClosedRange<Double>) -> Constraint<Double>
}

// MARK: - Array Constraints

extension Constraint where Value == [Any] {
    public static func minItems(_ count: Int) -> Constraint<[Any]>
    public static func maxItems(_ count: Int) -> Constraint<[Any]>
    public static var uniqueItems: Constraint<[Any]>
}
```

**Implementation Tasks**:
- [ ] Create `Constraint` struct with internal `Kind` enum
- [ ] Implement static factory methods for each constraint type
- [ ] Add `Equatable` conformance
- [ ] Write tests for constraint creation

---

### 1.4 Generable Protocol

**File**: `Sources/SwiftAI/Core/Protocols/Generable.swift`

Protocol for types that can be generated by LLMs.

```swift
/// A type that can be generated by language models
public protocol Generable: GenerableContentConvertible, Sendable {
    /// The partial type used for streaming responses
    associatedtype Partial: GenerableContentConvertible, Sendable

    /// The schema describing the structure and constraints of this type
    static var schema: Schema { get }
}

/// A type that can be converted to and from StructuredContent
public protocol GenerableContentConvertible {
    /// The structured representation of this instance
    var generableContent: StructuredContent { get }

    /// Creates an instance from structured content
    init(from structuredContent: StructuredContent) throws
}

// MARK: - Built-in Conformances

extension String: Generable {
    public typealias Partial = String

    public static var schema: Schema {
        .string(constraints: [])
    }

    public var generableContent: StructuredContent {
        StructuredContent(kind: .string(self))
    }

    public init(from structuredContent: StructuredContent) throws {
        self = try structuredContent.string
    }
}

extension Int: Generable {
    public typealias Partial = Int

    public static var schema: Schema {
        .integer(constraints: [])
    }

    public var generableContent: StructuredContent {
        StructuredContent(kind: .number(Double(self)))
    }

    public init(from structuredContent: StructuredContent) throws {
        self = try structuredContent.int
    }
}

extension Double: Generable {
    public typealias Partial = Double

    public static var schema: Schema {
        .number(constraints: [])
    }

    public var generableContent: StructuredContent {
        StructuredContent(kind: .number(self))
    }

    public init(from structuredContent: StructuredContent) throws {
        self = try structuredContent.double
    }
}

extension Bool: Generable {
    public typealias Partial = Bool

    public static var schema: Schema {
        .boolean(constraints: [])
    }

    public var generableContent: StructuredContent {
        StructuredContent(kind: .bool(self))
    }

    public init(from structuredContent: StructuredContent) throws {
        self = try structuredContent.bool
    }
}

extension Optional: GenerableContentConvertible where Wrapped: GenerableContentConvertible {
    public var generableContent: StructuredContent {
        switch self {
        case .none:
            return StructuredContent(kind: .null)
        case .some(let value):
            return value.generableContent
        }
    }

    public init(from structuredContent: StructuredContent) throws {
        if structuredContent.isNull {
            self = .none
        } else {
            self = .some(try Wrapped(from: structuredContent))
        }
    }
}

extension Optional: Generable where Wrapped: Generable {
    public typealias Partial = Wrapped.Partial?

    public static var schema: Schema {
        .optional(wrapped: Wrapped.schema)
    }
}

extension Array: GenerableContentConvertible where Element: GenerableContentConvertible {
    public var generableContent: StructuredContent {
        StructuredContent(kind: .array(self.map { $0.generableContent }))
    }

    public init(from structuredContent: StructuredContent) throws {
        let array = try structuredContent.array
        self = try array.map { try Element(from: $0) }
    }
}

extension Array: Generable where Element: Generable {
    public typealias Partial = [Element.Partial]

    public static var schema: Schema {
        .array(items: Element.schema, constraints: [])
    }
}
```

**Implementation Tasks**:
- [ ] Create `Generable` protocol with associated types
- [ ] Create `GenerableContentConvertible` protocol
- [ ] Implement conformances for `String`, `Int`, `Double`, `Bool`
- [ ] Implement conformances for `Optional` and `Array`
- [ ] Write comprehensive tests

---

### 1.5 Phase 1 Checklist

- [ ] Create `StructuredContent.swift`
- [ ] Create `Schema.swift`
- [ ] Create `Constraint.swift`
- [ ] Create `Generable.swift`
- [ ] Add `OrderedCollections` to Package.swift
- [ ] Write unit tests for all types
- [ ] Update module exports in `SwiftAI.swift`

---

## Phase 2: Macro System

**Duration**: Week 2-3
**Priority**: Critical
**Dependencies**: Phase 1

### 2.1 Package.swift Updates

Add macro target and dependencies:

```swift
// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftAI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        // ...
    ],
    products: [
        .library(name: "SwiftAI", targets: ["SwiftAI"]),
    ],
    dependencies: [
        // Existing dependencies...

        // Swift Syntax for macros
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),

        // Ordered collections
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    ],
    targets: [
        // Macro implementation target
        .macro(
            name: "SwiftAIMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),

        // Main library target
        .target(
            name: "SwiftAI",
            dependencies: [
                "SwiftAIMacros",
                .product(name: "OrderedCollections", package: "swift-collections"),
                // Other existing dependencies...
            ]
        ),

        // Macro tests
        .testTarget(
            name: "SwiftAIMacrosTests",
            dependencies: [
                "SwiftAIMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
```

---

### 2.2 Macro Declarations

**File**: `Sources/SwiftAI/Core/Macros/GenerableMacros.swift`

```swift
// MARK: - @Generable Macro Declaration

/// Conforms types to Generable by generating schema, serialization, and Partial type
///
/// ## Example
///
/// ```swift
/// @Generable
/// struct Recipe {
///     @Guide("Recipe title")
///     let title: String
///
///     @Guide("List of ingredients")
///     let ingredients: [String]
///
///     @Guide("Cooking time in minutes", .minimum(1))
///     let cookTime: Int
/// }
/// ```
///
/// The macro generates:
/// - `static var schema: Schema` - Type structure for LLM
/// - `var generableContent: StructuredContent` - Instance to JSON
/// - `init(from:)` - JSON to instance
/// - `struct Partial` - For streaming with optional fields
@attached(
    extension,
    conformances: Generable,
    names: named(schema), named(generableContent), named(Partial), named(init(from:))
)
public macro Generable(description: String? = nil) =
    #externalMacro(module: "SwiftAIMacros", type: "GenerableMacro")

// MARK: - @Guide Macro Declaration

/// Provides generation guidance for properties in Generable types
///
/// ## Simple Description
/// ```swift
/// @Guide("The user's email address")
/// let email: String
/// ```
///
/// ## With Constraints
/// ```swift
/// @Guide("Age in years", .minimum(0), .maximum(150))
/// let age: Int
///
/// @Guide("Product SKU", .pattern("[A-Z]{3}-\\d{4}"))
/// let sku: String
/// ```
@attached(peer)
public macro Guide(description: String) =
    #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")

@attached(peer)
public macro Guide<T>(description: String? = nil, _ constraints: Constraint<T>...) =
    #externalMacro(module: "SwiftAIMacros", type: "GuideMacro")
```

---

### 2.3 GenerableMacro Implementation

**File**: `Sources/SwiftAIMacros/GenerableMacro.swift`

```swift
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin

public struct GenerableMacro: ExtensionMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        // 1. Parse the declaration (struct or class)
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw GenerableMacroError.onlyStructsSupported
        }

        let typeName = structDecl.name.text
        let members = parseMembers(from: structDecl)

        // 2. Generate extension with all required implementations
        let extensionDecl = try ExtensionDeclSyntax("extension \(raw: typeName): Generable") {
            // Generate schema
            try generateSchemaDeclaration(typeName: typeName, members: members)

            // Generate generableContent
            try generateContentDeclaration(members: members)

            // Generate init(from:)
            try generateInitDeclaration(members: members)

            // Generate Partial struct
            try generatePartialDeclaration(typeName: typeName, members: members)
        }

        return [extensionDecl]
    }

    // MARK: - Member Parsing

    private struct ParsedMember {
        let name: String
        let type: String
        let isOptional: Bool
        let description: String?
        let constraints: [String]
    }

    private static func parseMembers(from structDecl: StructDeclSyntax) -> [ParsedMember] {
        var members: [ParsedMember] = []

        for member in structDecl.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let binding = varDecl.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
                  let typeAnnotation = binding.typeAnnotation else {
                continue
            }

            let name = identifier.identifier.text
            let type = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
            let isOptional = type.hasSuffix("?")

            // Parse @Guide attributes
            var description: String? = nil
            var constraints: [String] = []

            for attribute in varDecl.attributes {
                if let attr = attribute.as(AttributeSyntax.self),
                   attr.attributeName.description == "Guide" {
                    // Extract description and constraints from @Guide
                    (description, constraints) = parseGuideAttribute(attr)
                }
            }

            members.append(ParsedMember(
                name: name,
                type: type,
                isOptional: isOptional,
                description: description,
                constraints: constraints
            ))
        }

        return members
    }

    // MARK: - Schema Generation

    private static func generateSchemaDeclaration(
        typeName: String,
        members: [ParsedMember]
    ) throws -> DeclSyntax {
        var propertyLines: [String] = []

        for member in members {
            let schemaType = schemaTypeFor(member.type)
            let descParam = member.description.map { ", description: \"\($0)\"" } ?? ""
            let required = !member.isOptional

            propertyLines.append("""
                "\(member.name)": .init(schema: \(schemaType)\(descParam), isRequired: \(required))
            """)
        }

        let propertiesString = propertyLines.joined(separator: ",\n            ")

        return """
        public static var schema: Schema {
            .object(
                name: "\(raw: typeName)",
                description: nil,
                properties: [
                    \(raw: propertiesString)
                ]
            )
        }
        """
    }

    // MARK: - Content Generation

    private static func generateContentDeclaration(members: [ParsedMember]) throws -> DeclSyntax {
        var lines: [String] = []

        for member in members {
            lines.append("\"\(member.name)\": self.\(member.name).generableContent")
        }

        let objectLiteral = lines.joined(separator: ",\n            ")

        return """
        public var generableContent: StructuredContent {
            StructuredContent(kind: .object([
                \(raw: objectLiteral)
            ]))
        }
        """
    }

    // MARK: - Init Generation

    private static func generateInitDeclaration(members: [ParsedMember]) throws -> DeclSyntax {
        var lines: [String] = []

        for member in members {
            let baseType = member.type.replacingOccurrences(of: "?", with: "")

            if member.isOptional {
                lines.append("""
                    self.\(member.name) = try? obj["\(member.name)"].map { try \(baseType)(from: $0) }
                """)
            } else {
                lines.append("""
                    guard let \(member.name)Content = obj["\(member.name)"] else {
                        throw StructuredContentError.missingKey("\(member.name)")
                    }
                    self.\(member.name) = try \(baseType)(from: \(member.name)Content)
                """)
            }
        }

        let initBody = lines.joined(separator: "\n        ")

        return """
        public init(from structuredContent: StructuredContent) throws {
            let obj = try structuredContent.object
            \(raw: initBody)
        }
        """
    }

    // MARK: - Partial Generation

    private static func generatePartialDeclaration(
        typeName: String,
        members: [ParsedMember]
    ) throws -> DeclSyntax {
        var propertyDecls: [String] = []
        var initLines: [String] = []

        for member in members {
            let partialType = partialTypeFor(member.type)
            propertyDecls.append("public var \(member.name): \(partialType)?")
            initLines.append("self.\(member.name) = try? obj[\"\(member.name)\"].map { try \(partialType)(from: $0) }")
        }

        let properties = propertyDecls.joined(separator: "\n        ")
        let initBody = initLines.joined(separator: "\n            ")

        return """
        public struct Partial: GenerableContentConvertible, Sendable {
            \(raw: properties)

            public init() {}

            public init(from structuredContent: StructuredContent) throws {
                guard case .object(let obj) = structuredContent.kind else {
                    return
                }
                \(raw: initBody)
            }

            public var generableContent: StructuredContent {
                var obj: [String: StructuredContent] = [:]
                // Add non-nil fields...
                return StructuredContent(kind: .object(obj))
            }
        }
        """
    }

    // MARK: - Helpers

    private static func schemaTypeFor(_ swiftType: String) -> String {
        let baseType = swiftType.replacingOccurrences(of: "?", with: "")

        switch baseType {
        case "String": return ".string(constraints: [])"
        case "Int": return ".integer(constraints: [])"
        case "Double": return ".number(constraints: [])"
        case "Bool": return ".boolean(constraints: [])"
        default:
            if baseType.hasPrefix("[") && baseType.hasSuffix("]") {
                let elementType = String(baseType.dropFirst().dropLast())
                return ".array(items: \(schemaTypeFor(elementType)), constraints: [])"
            }
            return "\(baseType).schema"
        }
    }

    private static func partialTypeFor(_ swiftType: String) -> String {
        let baseType = swiftType.replacingOccurrences(of: "?", with: "")

        switch baseType {
        case "String", "Int", "Double", "Bool":
            return baseType
        default:
            if baseType.hasPrefix("[") {
                return baseType
            }
            return "\(baseType).Partial"
        }
    }
}

// MARK: - Errors

enum GenerableMacroError: Error, CustomStringConvertible {
    case onlyStructsSupported
    case invalidMemberDeclaration

    var description: String {
        switch self {
        case .onlyStructsSupported:
            return "@Generable can only be applied to structs"
        case .invalidMemberDeclaration:
            return "Invalid member declaration"
        }
    }
}
```

---

### 2.4 GuideMacro Implementation

**File**: `Sources/SwiftAIMacros/GuideMacro.swift`

```swift
import SwiftSyntax
import SwiftSyntaxMacros

/// Peer macro that attaches metadata to properties
/// The GenerableMacro reads this metadata during expansion
public struct GuideMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // No code generation - just marks properties for GenerableMacro
        return []
    }
}
```

---

### 2.5 Compiler Plugin Registration

**File**: `Sources/SwiftAIMacros/SwiftAIMacrosPlugin.swift`

```swift
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SwiftAIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GenerableMacro.self,
        GuideMacro.self,
    ]
}
```

---

### 2.6 Phase 2 Checklist

- [ ] Update Package.swift with macro target
- [ ] Create `GenerableMacros.swift` with declarations
- [ ] Implement `GenerableMacro.swift` (~800 lines)
- [ ] Implement `GuideMacro.swift`
- [ ] Create `SwiftAIMacrosPlugin.swift`
- [ ] Write macro expansion tests
- [ ] Test with real structs and nested types

---

## Phase 3: Streaming & JsonRepair

**Duration**: Week 3-4
**Priority**: High
**Dependencies**: Phase 1, Phase 2

### 3.1 JsonRepair Utility

**File**: `Sources/SwiftAI/Utilities/JsonRepair.swift`

```swift
import Foundation

/// Repairs incomplete JSON strings for streaming parsing
///
/// This utility enables parsing partial JSON responses during streaming,
/// allowing UI to update progressively as fields complete.
///
/// ## Example
///
/// ```swift
/// let incomplete = #"{"name": "Jo"#
/// let repaired = repair(json: incomplete)
/// // Returns: #"{"name": "Jo"}"#
/// ```
///
/// ## Behavior
///
/// - Closes unclosed strings
/// - Closes unclosed objects and arrays
/// - Backtracks to last valid value on incomplete data
/// - Non-string partials are not recovered (e.g., `[1, 2` → `[1]`)
public func repair(json: String) -> String {
    if json.isEmpty {
        return ""
    }

    var chars = Array(json)

    // Tracking state while scanning
    var inString = false
    var escapeNext = false
    var containersStack = [Container]()

    // Scan the input string
    for (i, c) in chars.enumerated() {
        if inString {
            if escapeNext {
                escapeNext = false
            } else if c == JSONChar.backslash {
                escapeNext = true
            } else if c == JSONChar.quote {
                inString = false
            }
        } else {
            switch c {
            case JSONChar.quote:
                inString = true
            case JSONChar.openBrace:
                containersStack.append(Container(type: .object, openingIndex: i))
            case JSONChar.openBracket:
                containersStack.append(Container(type: .array, openingIndex: i))
            case JSONChar.closeBrace, JSONChar.closeBracket:
                if !containersStack.isEmpty {
                    containersStack.removeLast()
                }
            case JSONChar.comma:
                if var top = containersStack.popLast() {
                    top.lastCommaIndex = i
                    containersStack.append(top)
                }
            case JSONChar.colon:
                if var top = containersStack.popLast() {
                    top.lastColonIndex = i
                    containersStack.append(top)
                }
            default:
                break
            }
        }
    }

    // Repair unclosed string
    if inString {
        let backslashCount = countTrailingBackslashes(in: chars)
        if backslashCount % 2 == 1 {
            chars.removeLast()
        }
        chars.append(JSONChar.quote)
    }

    // Handle incomplete values
    guard let top = containersStack.last else {
        return String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let firstContainer = containersStack.first!

    if !isCompleteValue(in: top, chars: chars) {
        while let current = containersStack.last {
            if let idx = current.lastCommaIndex {
                chars = Array(chars.prefix(upTo: idx))
                break
            } else {
                chars = Array(chars.prefix(upTo: current.openingIndex))
                containersStack.removeLast()
            }
        }
    }

    // Close remaining containers
    while let top = containersStack.popLast() {
        chars.append(top.type == .object ? JSONChar.closeBrace : JSONChar.closeBracket)
    }

    let result = String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
    if result.isEmpty {
        return firstContainer.type == .object ? "{}" : "[]"
    }
    return result
}

// MARK: - Private Types

private enum ContainerType { case object, array }

private struct Container {
    var type: ContainerType
    var openingIndex: Int
    var lastCommaIndex: Int?
    var lastColonIndex: Int?

    func isExpectingValue() -> Bool {
        if type == .array { return true }
        guard let lastColonIndex else { return false }
        let lastBorderIndex = lastCommaIndex ?? openingIndex
        return lastBorderIndex < lastColonIndex
    }
}

private enum JSONChar {
    static let openBrace: Character = "{"
    static let closeBrace: Character = "}"
    static let openBracket: Character = "["
    static let closeBracket: Character = "]"
    static let quote: Character = "\""
    static let comma: Character = ","
    static let colon: Character = ":"
    static let backslash: Character = "\\"
}

private func isCompleteValue(in container: Container, chars: [Character]) -> Bool {
    guard container.isExpectingValue() else { return false }
    let trimmed = chars.reversed().drop(while: { $0.isWhitespace }).reversed()
    guard let last = trimmed.last else { return false }

    if last == JSONChar.quote { return true }

    return endsWithLiteral(trimmed, literal: "true")
        || endsWithLiteral(trimmed, literal: "false")
        || endsWithLiteral(trimmed, literal: "null")
}

private func endsWithLiteral<C: Collection>(_ chars: C, literal: String) -> Bool
    where C.Element == Character {
    guard chars.count >= literal.count else { return false }
    return String(chars.suffix(literal.count)) == literal
}

private func countTrailingBackslashes(in chars: [Character]) -> Int {
    var count = 0
    var index = chars.count - 1
    while index >= 0 && chars[index] == JSONChar.backslash {
        count += 1
        index -= 1
    }
    return count
}
```

---

### 3.2 Streaming Provider Extension

**File**: `Sources/SwiftAI/Providers/Extensions/AIProvider+Streaming.swift`

```swift
import Foundation

extension AIProvider {

    /// Stream structured output with progressive partial updates
    ///
    /// This method enables real-time UI updates as the LLM generates content.
    /// Each yielded partial contains the fields completed so far.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Generable
    /// struct Recipe {
    ///     let title: String
    ///     let ingredients: [String]
    /// }
    ///
    /// for try await partial in provider.stream("Give me a pasta recipe", returning: Recipe.self) {
    ///     if let title = partial.title {
    ///         titleLabel.text = title  // Updates progressively
    ///     }
    ///     if let ingredients = partial.ingredients {
    ///         ingredientsList = ingredients
    ///     }
    /// }
    /// ```
    public func stream<T: Generable>(
        _ prompt: String,
        returning type: T.Type,
        model: ModelIdentifier,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<T.Partial, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var accumulated = ""

                do {
                    for try await chunk in self.stream(prompt, model: model, config: config) {
                        accumulated += chunk

                        // Repair incomplete JSON
                        let repaired = repair(json: accumulated)

                        // Try to parse as structured content
                        if !repaired.isEmpty,
                           let content = try? StructuredContent(json: repaired) {
                            do {
                                let partial = try T.Partial(from: content)
                                continuation.yield(partial)
                            } catch {
                                // Parsing failed, continue accumulating
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Stream with final complete object
    ///
    /// Returns an async sequence that yields partials during streaming,
    /// then yields the final complete object.
    public func streamWithCompletion<T: Generable>(
        _ prompt: String,
        returning type: T.Type,
        model: ModelIdentifier,
        config: GenerateConfig = .default
    ) -> AsyncThrowingStream<StreamingResult<T>, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var accumulated = ""
                var lastPartial: T.Partial?

                do {
                    for try await chunk in self.stream(prompt, model: model, config: config) {
                        accumulated += chunk

                        let repaired = repair(json: accumulated)
                        if !repaired.isEmpty,
                           let content = try? StructuredContent(json: repaired),
                           let partial = try? T.Partial(from: content) {
                            lastPartial = partial
                            continuation.yield(.partial(partial))
                        }
                    }

                    // Parse final complete object
                    let content = try StructuredContent(json: accumulated)
                    let complete = try T(from: content)
                    continuation.yield(.complete(complete))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// Result type for streaming with completion
public enum StreamingResult<T: Generable> {
    case partial(T.Partial)
    case complete(T)
}
```

---

### 3.3 Phase 3 Checklist

- [ ] Implement `JsonRepair.swift`
- [ ] Write JsonRepair unit tests
- [ ] Implement `AIProvider+Streaming.swift` extension
- [ ] Add `StreamingResult` enum
- [ ] Test streaming with real LLM providers
- [ ] Test partial parsing with various JSON structures

---

## Phase 4: Tool Protocol

**Duration**: Week 4-5
**Priority**: High
**Dependencies**: Phase 1, Phase 2

### 4.1 Tool Protocol

**File**: `Sources/SwiftAI/Core/Protocols/Tool.swift`

```swift
import Foundation

/// A function that language models can invoke to perform specific tasks
///
/// Tools extend LLM capabilities by providing access to external functions,
/// APIs, and data sources with full type safety.
///
/// ## Example
///
/// ```swift
/// struct WeatherTool: Tool {
///     @Generable
///     struct Arguments {
///         @Guide("City name")
///         let city: String
///
///         @Guide("Temperature unit", .anyOf(["celsius", "fahrenheit"]))
///         let unit: String?
///     }
///
///     let description = "Get weather for a city"
///
///     func call(arguments: Arguments) async throws -> String {
///         let unit = arguments.unit ?? "celsius"
///         return "Weather in \(arguments.city): 22°\(unit == "celsius" ? "C" : "F")"
///     }
/// }
/// ```
public protocol Tool: Sendable {
    /// The input parameters required to execute this tool
    associatedtype Arguments: Generable

    /// The output type returned by this tool
    associatedtype Output: PromptRepresentable

    /// A unique name for this tool (used by LLM to reference it)
    var name: String { get }

    /// A natural language description for the LLM
    var description: String { get }

    /// The schema specification of parameters this tool accepts
    static var parameters: Schema { get }

    /// Execute the tool with typed arguments
    func call(arguments: Arguments) async throws -> Output

    /// Execute the tool from JSON-encoded arguments
    func call(_ data: Data) async throws -> any PromptRepresentable
}

// MARK: - Default Implementations

extension Tool where Arguments: Generable {
    /// Default name uses type name
    public var name: String {
        String(describing: Self.self)
    }

    /// Default parameters from Arguments schema
    public static var parameters: Schema {
        Arguments.schema
    }

    /// Default JSON call implementation
    public func call(_ data: Data) async throws -> any PromptRepresentable {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ToolError.invalidArgumentEncoding
        }
        let content = try StructuredContent(json: jsonString)
        let arguments = try Arguments(from: content)
        return try await call(arguments: arguments)
    }
}

// MARK: - PromptRepresentable

/// A type that can be represented in a prompt
public protocol PromptRepresentable: Sendable {
    /// Convert to prompt chunks
    var promptChunks: [PromptChunk] { get }
}

extension String: PromptRepresentable {
    public var promptChunks: [PromptChunk] {
        [.text(self)]
    }
}

// MARK: - Errors

public enum ToolError: Error, LocalizedError {
    case toolNotFound(name: String)
    case invalidArgumentEncoding
    case executionFailed(tool: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .invalidArgumentEncoding:
            return "Invalid UTF-8 encoding in tool arguments"
        case .executionFailed(let tool, let error):
            return "Tool '\(tool)' execution failed: \(error.localizedDescription)"
        }
    }
}
```

---

### 4.2 Tool Message Types

**File**: `Sources/SwiftAI/Core/Types/ToolMessage.swift`

```swift
import Foundation

/// A tool call made by the LLM
public struct ToolCall: Sendable, Equatable, Identifiable {
    public let id: String
    public let toolName: String
    public let arguments: StructuredContent

    public init(id: String, toolName: String, arguments: StructuredContent) {
        self.id = id
        self.toolName = toolName
        self.arguments = arguments
    }
}

/// The output from a tool execution
public struct ToolOutput: Sendable, Equatable {
    public let id: String
    public let toolName: String
    public let content: String

    public init(id: String, toolName: String, content: String) {
        self.id = id
        self.toolName = toolName
        self.content = content
    }
}

// MARK: - Message Extensions

extension Message {
    /// Create a tool output message
    public static func toolOutput(_ output: ToolOutput) -> Message {
        .init(
            role: .tool,
            content: output.content,
            toolCallId: output.id,
            toolName: output.toolName
        )
    }
}
```

---

### 4.3 Tool Execution Loop

**File**: `Sources/SwiftAI/Core/ToolExecutor.swift`

```swift
import Foundation

/// Executes tools in an agent loop until no more tool calls
public actor ToolExecutor {
    private let tools: [any Tool]
    private let provider: any AIProvider
    private let model: ModelIdentifier

    public init(
        tools: [any Tool],
        provider: any AIProvider,
        model: ModelIdentifier
    ) {
        self.tools = tools
        self.provider = provider
        self.model = model
    }

    /// Execute a prompt with automatic tool calling
    public func execute(
        messages: [Message],
        config: GenerateConfig = .default
    ) async throws -> ToolExecutionResult {
        var currentMessages = messages
        var allToolCalls: [ToolCall] = []
        var iterations = 0
        let maxIterations = 10

        while iterations < maxIterations {
            iterations += 1

            // Generate response with tools
            let response = try await provider.generateWithTools(
                messages: currentMessages,
                tools: tools,
                model: model,
                config: config
            )

            // Add AI response to messages
            currentMessages.append(response.message)

            // Check for tool calls
            guard !response.toolCalls.isEmpty else {
                // No tool calls - return final response
                return ToolExecutionResult(
                    content: response.content,
                    toolCalls: allToolCalls,
                    messages: currentMessages,
                    iterations: iterations
                )
            }

            // Execute all tool calls
            for toolCall in response.toolCalls {
                allToolCalls.append(toolCall)

                let output = try await executeToolCall(toolCall)
                currentMessages.append(.toolOutput(output))
            }
        }

        throw ToolError.executionFailed(
            tool: "agent",
            underlying: NSError(domain: "SwiftAI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Max iterations exceeded"
            ])
        )
    }

    private func executeToolCall(_ toolCall: ToolCall) async throws -> ToolOutput {
        guard let tool = tools.first(where: { $0.name == toolCall.toolName }) else {
            throw ToolError.toolNotFound(name: toolCall.toolName)
        }

        let argumentsData = try toolCall.arguments.toData()
        let result = try await tool.call(argumentsData)

        return ToolOutput(
            id: toolCall.id,
            toolName: toolCall.toolName,
            content: result.promptChunks.map { chunk in
                if case .text(let text) = chunk { return text }
                return ""
            }.joined()
        )
    }
}

/// Result of tool execution
public struct ToolExecutionResult: Sendable {
    public let content: String
    public let toolCalls: [ToolCall]
    public let messages: [Message]
    public let iterations: Int
}
```

---

### 4.4 Schema Conversion for Providers

**File**: `Sources/SwiftAI/Providers/Extensions/Schema+Anthropic.swift`

```swift
import Foundation

extension Schema {
    /// Convert to Anthropic JSON Schema format
    public func toAnthropicSchema() -> [String: Any] {
        switch self {
        case .string(let constraints):
            var schema: [String: Any] = ["type": "string"]
            applyStringConstraints(constraints, to: &schema)
            return schema

        case .integer(let constraints):
            var schema: [String: Any] = ["type": "integer"]
            applyNumericConstraints(constraints, to: &schema)
            return schema

        case .number(let constraints):
            var schema: [String: Any] = ["type": "number"]
            applyNumericConstraints(constraints, to: &schema)
            return schema

        case .boolean:
            return ["type": "boolean"]

        case .array(let items, let constraints):
            var schema: [String: Any] = [
                "type": "array",
                "items": items.toAnthropicSchema()
            ]
            applyArrayConstraints(constraints, to: &schema)
            return schema

        case .object(let name, let description, let properties):
            var schema: [String: Any] = [
                "type": "object",
                "title": name,
                "properties": Dictionary(uniqueKeysWithValues: properties.map { key, prop in
                    (key, prop.schema.toAnthropicSchema())
                }),
                "required": properties.filter { $0.value.isRequired }.map { $0.key },
                "additionalProperties": false
            ]
            if let description {
                schema["description"] = description
            }
            return schema

        case .optional(let wrapped):
            var schema = wrapped.toAnthropicSchema()
            // Mark as nullable
            if var types = schema["type"] as? [String] {
                types.append("null")
                schema["type"] = types
            } else if let type = schema["type"] as? String {
                schema["type"] = [type, "null"]
            }
            return schema

        case .anyOf(let name, let description, let schemas):
            var schema: [String: Any] = [
                "title": name,
                "anyOf": schemas.map { $0.toAnthropicSchema() }
            ]
            if let description {
                schema["description"] = description
            }
            return schema
        }
    }

    private func applyStringConstraints(_ constraints: [StringConstraint], to schema: inout [String: Any]) {
        for constraint in constraints {
            switch constraint.kind {
            case .pattern(let regex):
                schema["pattern"] = regex
            case .constant(let value):
                schema["enum"] = [value]
            case .anyOf(let values):
                schema["enum"] = values
            case .minLength(let length):
                schema["minLength"] = length
            case .maxLength(let length):
                schema["maxLength"] = length
            default:
                break
            }
        }
    }

    private func applyNumericConstraints<T>(_ constraints: [Constraint<T>], to schema: inout [String: Any]) {
        for constraint in constraints {
            switch constraint.kind {
            case .minimum(let value):
                schema["minimum"] = value
            case .maximum(let value):
                schema["maximum"] = value
            case .exclusiveMinimum(let value):
                schema["exclusiveMinimum"] = value
            case .exclusiveMaximum(let value):
                schema["exclusiveMaximum"] = value
            case .multipleOf(let value):
                schema["multipleOf"] = value
            default:
                break
            }
        }
    }

    private func applyArrayConstraints(_ constraints: [ArrayConstraint], to schema: inout [String: Any]) {
        for constraint in constraints {
            switch constraint.kind {
            case .minItems(let count):
                schema["minItems"] = count
            case .maxItems(let count):
                schema["maxItems"] = count
            case .uniqueItems:
                schema["uniqueItems"] = true
            default:
                break
            }
        }
    }
}
```

---

### 4.5 Phase 4 Checklist

- [ ] Implement `Tool.swift` protocol
- [ ] Implement `ToolMessage.swift` types
- [ ] Implement `ToolExecutor.swift`
- [ ] Implement `Schema+Anthropic.swift`
- [ ] Implement `Schema+OpenAI.swift`
- [ ] Add tool support to `AnthropicProvider`
- [ ] Add tool support to `OpenAIProvider`
- [ ] Write tool protocol tests
- [ ] Write tool execution loop tests

---

## Phase 5: SwiftAgents Integration

**Duration**: Week 5-6
**Priority**: Medium
**Dependencies**: Phase 1-4

### 5.1 SwiftAI Inference Adapter

**File**: `Sources/SwiftAI/Integration/SwiftAgentsAdapter.swift`

```swift
import Foundation

#if canImport(SwiftAgents)
import SwiftAgents

/// Bridges SwiftAI providers to SwiftAgents InferenceProvider
///
/// ## Example
///
/// ```swift
/// let anthropicProvider = AnthropicProvider(apiKey: "...")
/// let inferenceProvider = SwiftAIInferenceProvider(
///     provider: anthropicProvider,
///     model: .claude35Sonnet
/// )
///
/// let agent = ReActAgent.Builder()
///     .inferenceProvider(inferenceProvider)
///     .build()
/// ```
public struct SwiftAIInferenceProvider: InferenceProvider, Sendable {
    private let provider: any AIProvider
    private let model: ModelIdentifier

    public init(provider: any AIProvider, model: ModelIdentifier) {
        self.provider = provider
        self.model = model
    }

    // MARK: - InferenceProvider Conformance

    public func generate(
        prompt: String,
        options: InferenceOptions
    ) async throws -> String {
        try await provider.generate(
            prompt,
            model: model,
            config: options.toGenerateConfig()
        )
    }

    public func stream(
        prompt: String,
        options: InferenceOptions
    ) -> AsyncThrowingStream<String, Error> {
        provider.stream(prompt, model: model, config: options.toGenerateConfig())
    }

    public func generateWithToolCalls(
        prompt: String,
        tools: [ToolDefinition],
        options: InferenceOptions
    ) async throws -> InferenceResponse {
        // Convert SwiftAgents ToolDefinitions to SwiftAI format
        let swiftAITools = tools.map { SwiftAgentsToolAdapter(definition: $0) }

        // Generate with tools
        let response = try await provider.generateWithTools(
            messages: [.user(prompt)],
            tools: swiftAITools,
            model: model,
            config: options.toGenerateConfig()
        )

        // Convert response
        return InferenceResponse(
            content: response.content,
            toolCalls: response.toolCalls.map { call in
                SwiftAgents.ToolCall(
                    id: call.id,
                    name: call.toolName,
                    arguments: try? call.arguments.toJSON() ?? "{}"
                )
            },
            finishReason: response.finishReason.toSwiftAgentsReason()
        )
    }
}

// MARK: - Tool Adapter

/// Adapts SwiftAgents ToolDefinition to SwiftAI Tool protocol
private struct SwiftAgentsToolAdapter: Tool {
    typealias Arguments = DynamicArguments
    typealias Output = String

    let definition: ToolDefinition

    var name: String { definition.name }
    var description: String { definition.description }

    static var parameters: Schema {
        // Dynamic schema based on definition
        .object(name: "Arguments", description: nil, properties: [:])
    }

    func call(arguments: DynamicArguments) async throws -> String {
        // This shouldn't be called directly - SwiftAgents handles execution
        throw ToolError.executionFailed(
            tool: name,
            underlying: NSError(domain: "SwiftAI", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "SwiftAgents tools should be executed by SwiftAgents"
            ])
        )
    }
}

/// Dynamic arguments for SwiftAgents tool calls
struct DynamicArguments: Generable {
    typealias Partial = DynamicArguments

    let content: StructuredContent

    static var schema: Schema {
        .object(name: "DynamicArguments", description: nil, properties: [:])
    }

    var generableContent: StructuredContent { content }

    init(from structuredContent: StructuredContent) throws {
        self.content = structuredContent
    }
}

// MARK: - Extensions

extension InferenceOptions {
    /// Convert to SwiftAI GenerateConfig
    func toGenerateConfig() -> GenerateConfig {
        GenerateConfig.default
            .temperature(Float(temperature ?? 0.7))
            .maxTokens(maxTokens ?? 4096)
    }
}

extension FinishReason {
    func toSwiftAgentsReason() -> SwiftAgents.FinishReason {
        switch self {
        case .stop: return .completed
        case .length: return .length
        case .toolCalls: return .toolUse
        case .contentFilter: return .contentFilter
        }
    }
}
#endif
```

---

### 5.2 Structured Output for SwiftAgents

**File**: `Sources/SwiftAI/Integration/SwiftAgentsGenerable.swift`

```swift
#if canImport(SwiftAgents)
import SwiftAgents

extension SwiftAIInferenceProvider {
    /// Generate structured output with type safety
    ///
    /// Extends SwiftAgents with SwiftAI's @Generable type safety.
    ///
    /// ## Example
    ///
    /// ```swift
    /// @Generable
    /// struct TaskPlan {
    ///     let steps: [String]
    ///     let estimatedTime: Int
    /// }
    ///
    /// let plan: TaskPlan = try await inferenceProvider.generate(
    ///     prompt: "Plan a project",
    ///     returning: TaskPlan.self
    /// )
    /// ```
    public func generate<T: Generable>(
        prompt: String,
        returning type: T.Type,
        options: InferenceOptions = .default
    ) async throws -> T {
        let response = try await provider.generate(
            messages: [.user(prompt)],
            returning: type,
            model: model,
            config: options.toGenerateConfig()
        )
        return response
    }

    /// Stream structured output with partial updates
    public func stream<T: Generable>(
        prompt: String,
        returning type: T.Type,
        options: InferenceOptions = .default
    ) -> AsyncThrowingStream<T.Partial, Error> {
        provider.stream(
            prompt,
            returning: type,
            model: model,
            config: options.toGenerateConfig()
        )
    }
}
#endif
```

---

### 5.3 Package.swift Integration

Add conditional SwiftAgents dependency:

```swift
// In Package.swift dependencies
dependencies: [
    // ... existing dependencies

    // Optional SwiftAgents integration
    .package(url: "https://github.com/christopherkarani/SwiftAgents.git", from: "1.0.0"),
],

// In SwiftAI target
.target(
    name: "SwiftAI",
    dependencies: [
        "SwiftAIMacros",
        .product(name: "OrderedCollections", package: "swift-collections"),
        // Optional SwiftAgents
        .product(name: "SwiftAgents", package: "SwiftAgents", condition: .when(platforms: [.macOS, .iOS])),
    ]
)
```

---

### 5.4 Phase 5 Checklist

- [ ] Implement `SwiftAgentsAdapter.swift`
- [ ] Implement `SwiftAgentsGenerable.swift`
- [ ] Update Package.swift with optional dependency
- [ ] Write adapter tests
- [ ] Test with ReActAgent
- [ ] Test with memory systems
- [ ] Document integration patterns

---

## File Structure

Final directory structure after implementation:

```
Sources/
├── SwiftAI/
│   ├── SwiftAI.swift                          # Module exports
│   ├── Core/
│   │   ├── Protocols/
│   │   │   ├── AIProvider.swift               # Existing
│   │   │   ├── Generable.swift                # NEW
│   │   │   └── Tool.swift                     # NEW
│   │   ├── Types/
│   │   │   ├── Message.swift                  # Existing
│   │   │   ├── StructuredContent.swift        # NEW
│   │   │   ├── Schema.swift                   # NEW
│   │   │   ├── Constraint.swift               # NEW
│   │   │   └── ToolMessage.swift              # NEW
│   │   ├── Macros/
│   │   │   └── GenerableMacros.swift          # NEW (declarations)
│   │   └── ToolExecutor.swift                 # NEW
│   ├── Providers/
│   │   ├── Anthropic/
│   │   │   ├── AnthropicProvider.swift        # Existing
│   │   │   └── AnthropicProvider+Tools.swift  # NEW
│   │   ├── OpenAI/
│   │   │   ├── OpenAIProvider.swift           # Existing
│   │   │   └── OpenAIProvider+Tools.swift     # NEW
│   │   └── Extensions/
│   │       ├── AIProvider+Streaming.swift     # NEW
│   │       ├── Schema+Anthropic.swift         # NEW
│   │       └── Schema+OpenAI.swift            # NEW
│   ├── Utilities/
│   │   └── JsonRepair.swift                   # NEW
│   └── Integration/
│       ├── SwiftAgentsAdapter.swift           # NEW
│       └── SwiftAgentsGenerable.swift         # NEW
│
├── SwiftAIMacros/                             # NEW TARGET
│   ├── SwiftAIMacrosPlugin.swift
│   ├── GenerableMacro.swift
│   └── GuideMacro.swift
│
└── Tests/
    ├── SwiftAITests/
    │   ├── StructuredContentTests.swift       # NEW
    │   ├── SchemaTests.swift                  # NEW
    │   ├── ConstraintTests.swift              # NEW
    │   ├── GenerableTests.swift               # NEW
    │   ├── ToolTests.swift                    # NEW
    │   ├── JsonRepairTests.swift              # NEW
    │   └── StreamingTests.swift               # NEW
    └── SwiftAIMacrosTests/                    # NEW TARGET
        └── GenerableMacroTests.swift
```

---

## Dependencies

### Required New Dependencies

```swift
// Package.swift
dependencies: [
    // For macros
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),

    // For ordered properties in schemas
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),

    // Optional: SwiftAgents integration
    .package(url: "https://github.com/christopherkarani/SwiftAgents.git", from: "1.0.0"),
]
```

---

## Testing Strategy

### Unit Tests

| Component | Test File | Coverage |
|-----------|-----------|----------|
| StructuredContent | `StructuredContentTests.swift` | JSON parsing, type accessors, errors |
| Schema | `SchemaTests.swift` | All schema types, constraints |
| Constraint | `ConstraintTests.swift` | All constraint factories |
| Generable | `GenerableTests.swift` | Built-in conformances |
| JsonRepair | `JsonRepairTests.swift` | Edge cases, incomplete JSON |
| Tool | `ToolTests.swift` | Protocol, execution |
| Macro | `GenerableMacroTests.swift` | Code generation |

### Integration Tests

| Test | Description |
|------|-------------|
| Anthropic + Generable | Structured output with Anthropic |
| OpenAI + Generable | Structured output with OpenAI |
| Streaming + Partial | Progressive parsing during streaming |
| Tool Execution Loop | Multi-turn tool calling |
| SwiftAgents + SwiftAI | Agent with type-safe inference |

---

## Migration Guide

### For Existing Users

1. **No Breaking Changes**: All existing APIs remain unchanged
2. **Opt-in Features**: @Generable is additive
3. **Gradual Adoption**: Start using @Generable for new types

### Example Migration

**Before** (string-based):
```swift
let response = try await provider.generate("Give me a recipe", model: .claude35Sonnet)
let recipe = try JSONDecoder().decode(Recipe.self, from: response.data(using: .utf8)!)
```

**After** (type-safe):
```swift
@Generable
struct Recipe {
    let title: String
    let ingredients: [String]
}

let recipe = try await provider.generate(
    "Give me a recipe",
    returning: Recipe.self,
    model: .claude35Sonnet
)
// recipe.title is String, recipe.ingredients is [String]
```

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| **Phase 1** | Week 1-2 | StructuredContent, Schema, Constraint, Generable |
| **Phase 2** | Week 2-3 | @Generable macro, @Guide macro |
| **Phase 3** | Week 3-4 | JsonRepair, streaming partials |
| **Phase 4** | Week 4-5 | Tool protocol, execution loop |
| **Phase 5** | Week 5-6 | SwiftAgents integration |

---

## Next Steps

1. **Review this plan** and provide feedback
2. **Start Phase 1** with core type system
3. **Iterate** based on testing results
4. **Document** as we implement

---

*Last Updated: December 27, 2025*
