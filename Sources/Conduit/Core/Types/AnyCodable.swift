// AnyCodable.swift
// Conduit

import Foundation

// MARK: - AnyCodable

/// Type-erased Codable wrapper for JSON values.
///
/// Used internally for decoding tool call arguments and API responses that may have
/// varying structures. Supports all JSON primitive types plus nested arrays and dictionaries.
///
/// ## Supported Types
/// - `null` (NSNull)
/// - `Bool`
/// - `Int`
/// - `Double`
/// - `String`
/// - `[AnyCodable]` (arrays)
/// - `[String: AnyCodable]` (dictionaries)
///
/// ## Thread Safety
/// `AnyCodable` is fully `Sendable` because the `Value` enum only contains
/// Sendable types. No `@unchecked` marker is needed.
internal struct AnyCodable: Codable, Sendable, Hashable {

    // MARK: - Value Enum

    /// All supported JSON value types.
    ///
    /// This enum provides type-safe storage for JSON values, ensuring
    /// proper `Sendable` and `Hashable` conformance without relying on
    /// `@unchecked` markers or string-based equality.
    enum Value: Sendable, Hashable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case array([AnyCodable])
        case object([String: AnyCodable])
    }

    // MARK: - Properties

    /// The wrapped value in type-safe enum form.
    let value: Value

    /// Access the underlying Swift value for serialization.
    ///
    /// Converts the type-safe `Value` enum back to standard Swift types
    /// for compatibility with APIs expecting `Any`.
    ///
    /// - Returns: The value as a standard Swift type:
    ///   - `.null` returns `NSNull()`
    ///   - `.bool` returns `Bool`
    ///   - `.int` returns `Int`
    ///   - `.double` returns `Double`
    ///   - `.string` returns `String`
    ///   - `.array` returns `[Any]`
    ///   - `.object` returns `[String: Any]`
    var anyValue: Any {
        switch value {
        case .null:
            return NSNull()
        case .bool(let b):
            return b
        case .int(let i):
            return i
        case .double(let d):
            return d
        case .string(let s):
            return s
        case .array(let a):
            return a.map { $0.anyValue }
        case .object(let o):
            return o.mapValues { $0.anyValue }
        }
    }

    // MARK: - Initialization

    /// Creates a new AnyCodable wrapper from a raw value.
    ///
    /// Converts the raw `Any` value to a type-safe `Value` enum case.
    /// Unsupported types are converted to `.null`.
    ///
    /// - Parameter rawValue: The value to wrap. Must be a JSON-compatible type.
    init(_ rawValue: Any) {
        switch rawValue {
        case is NSNull:
            self.value = .null
        case let b as Bool:
            self.value = .bool(b)
        case let i as Int:
            self.value = .int(i)
        case let d as Double:
            self.value = .double(d)
        case let s as String:
            self.value = .string(s)
        case let a as [Any]:
            self.value = .array(a.map { AnyCodable($0) })
        case let o as [String: Any]:
            self.value = .object(o.mapValues { AnyCodable($0) })
        default:
            // Fallback for unsupported types
            self.value = .null
        }
    }

    /// Creates a new AnyCodable wrapper from a type-safe Value.
    ///
    /// - Parameter value: The Value enum case to wrap.
    init(value: Value) {
        self.value = value
    }

    // MARK: - Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = .null
        } else if let bool = try? container.decode(Bool.self) {
            value = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            value = .int(int)
        } else if let double = try? container.decode(Double.self) {
            value = .double(double)
        } else if let string = try? container.decode(String.self) {
            value = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            value = .array(array)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = .object(dict)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let dict):
            try container.encode(dict)
        }
    }
}
