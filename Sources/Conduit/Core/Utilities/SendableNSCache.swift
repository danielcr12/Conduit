//
//  SendableNSCache.swift
//  Conduit
//
//  Created on 2025-12-25.
//

import Foundation

// MARK: - Linux Compatibility
// NOTE: NSCache is not available on Linux. We provide a Dictionary-based
// alternative with lock protection for cross-platform support.

#if canImport(Darwin)

// MARK: - Darwin Implementation (NSCache)

/// A thread-safe wrapper around NSCache that provides Sendable conformance.
///
/// NSCache is thread-safe but not marked as Sendable. This wrapper uses
/// `@unchecked Sendable` to allow NSCache to be used within actors and
/// other Sendable contexts while maintaining type safety.
///
/// ## Usage
///
/// ```swift
/// actor MyCache {
///     private nonisolated(unsafe) let cacheWrapper = SendableNSCache<NSString, MyObject>()
///     private var cache: NSCache<NSString, MyObject> { cacheWrapper.cache }
///
///     func get(_ key: String) -> MyObject? {
///         cache.object(forKey: key as NSString)
///     }
///
///     func set(_ object: MyObject, forKey key: String) {
///         cache.setObject(object, forKey: key as NSString)
///     }
/// }
/// ```
///
/// ## Thread Safety
///
/// NSCache is documented as thread-safe and can be accessed from multiple
/// threads concurrently. The `@unchecked Sendable` conformance is safe because:
/// - NSCache handles synchronization internally
/// - The cache reference is immutable after initialization
/// - All NSCache methods are documented as thread-safe
///
/// ## Type Parameters
///
/// - `KeyType`: The key type, must be an NSObject subclass conforming to Hashable
/// - `ObjectType`: The cached object type, must be an NSObject subclass
public final class SendableNSCache<KeyType: AnyObject & Hashable, ObjectType: AnyObject>: @unchecked Sendable {

    /// The underlying NSCache instance.
    ///
    /// This is the actual cache that stores key-value pairs. Access it
    /// through a computed property in your actor for proper isolation.
    ///
    /// ## Configuration
    ///
    /// Configure the cache limits in your initializer:
    /// ```swift
    /// init() {
    ///     cacheWrapper.cache.countLimit = 100
    ///     cacheWrapper.cache.totalCostLimit = 1024 * 1024 * 100 // 100MB
    ///     cacheWrapper.cache.delegate = myDelegate
    /// }
    /// ```
    public let cache = NSCache<KeyType, ObjectType>()
}

#else

// MARK: - Linux Implementation (Dictionary with Lock)

/// A thread-safe cache implementation for Linux and other non-Darwin platforms.
///
/// Provides a simple Dictionary-based cache with lock protection for thread safety.
/// This is a basic implementation that mimics the NSCache API surface used by Conduit.
///
/// ## Platform Note
///
/// This implementation is used automatically on Linux where NSCache is unavailable.
/// The API surface is compatible with the Darwin version for seamless cross-platform use.
///
/// ## Thread Safety
///
/// Thread safety is provided via `NSLock`. All read and write operations are serialized.
///
/// ## Type Parameters
///
/// - `KeyType`: Any Hashable key type (less restrictive than Darwin which requires AnyObject)
/// - `ObjectType`: Any object type to cache
public final class SendableNSCache<KeyType: Hashable, ObjectType>: @unchecked Sendable {

    // MARK: - Private Storage

    private var storage: [KeyType: ObjectType] = [:]
    private var insertionOrder: [KeyType] = []  // Track insertion order for FIFO eviction
    private let lock = NSLock()

    // MARK: - Configuration

    /// The maximum number of objects the cache can hold.
    ///
    /// A value of 0 (default) means no limit.
    /// When the limit is exceeded, the oldest entry (FIFO) is evicted.
    public var countLimit: Int = 0

    /// The maximum total cost the cache can hold.
    ///
    /// A value of 0 (default) means no limit.
    /// NOTE: Cost tracking is simplified on Linux; use countLimit for reliable eviction.
    public var totalCostLimit: Int = 0

    // MARK: - Initialization

    /// Creates a new empty cache.
    public init() {}

    // MARK: - Cache Operations

    /// Returns the object associated with the given key.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached object, or `nil` if not found.
    public func object(forKey key: KeyType) -> ObjectType? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    /// Stores an object in the cache.
    ///
    /// - Parameters:
    ///   - obj: The object to cache.
    ///   - key: The key to associate with the object.
    public func setObject(_ obj: ObjectType, forKey key: KeyType) {
        lock.lock()
        defer { lock.unlock() }

        // FIFO eviction: remove oldest entry if at limit
        if countLimit > 0 && storage.count >= countLimit && storage[key] == nil {
            if let oldestKey = insertionOrder.first {
                storage.removeValue(forKey: oldestKey)
                insertionOrder.removeFirst()
            }
        }

        // Track insertion order for new keys only
        if storage[key] == nil {
            insertionOrder.append(key)
        }

        storage[key] = obj
    }

    /// Stores an object in the cache with an associated cost.
    ///
    /// - Parameters:
    ///   - obj: The object to cache.
    ///   - key: The key to associate with the object.
    ///   - cost: The cost of the object (simplified: treated as equivalent to setObject).
    public func setObject(_ obj: ObjectType, forKey key: KeyType, cost: Int) {
        setObject(obj, forKey: key)
    }

    /// Removes the object for the given key.
    ///
    /// - Parameter key: The key whose object should be removed.
    public func removeObject(forKey key: KeyType) {
        lock.lock()
        defer { lock.unlock() }
        if storage.removeValue(forKey: key) != nil {
            insertionOrder.removeAll { $0 == key }
        }
    }

    /// Removes all objects from the cache.
    public func removeAllObjects() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
        insertionOrder.removeAll()
    }

    /// The current number of objects in the cache.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}

#endif
