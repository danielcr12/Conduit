// URLSessionAsyncBytes.swift
// Conduit
//
// Cross-platform async byte streaming for URLSession.
// On Apple platforms, uses native URLSession.bytes(for:).
// On Linux, provides a polyfill using URLSessionDataTask with delegate.

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Cross-Platform Byte Streaming

#if canImport(FoundationNetworking)

/// A cross-platform async sequence of bytes for streaming HTTP responses on Linux.
///
/// This type provides Linux compatibility for `URLSession.bytes(for:)` which is
/// only available on Apple platforms. It uses a delegate-based approach to
/// stream bytes as they arrive from the server.
///
/// ## Usage
///
/// ```swift
/// let (stream, response) = try await session.asyncBytes(for: request)
/// for try await byte in stream {
///     // Process byte
/// }
/// // Or iterate lines:
/// for try await line in stream.lines {
///     // Process line
/// }
/// ```
public struct URLSessionAsyncBytes: AsyncSequence, Sendable {
    public typealias Element = UInt8

    private let stream: AsyncThrowingStream<UInt8, Error>

    init(stream: AsyncThrowingStream<UInt8, Error>) {
        self.stream = stream
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: stream.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: AsyncThrowingStream<UInt8, Error>.AsyncIterator

        public mutating func next() async throws -> UInt8? {
            try await iterator.next()
        }
    }

    /// An async sequence of lines from the byte stream.
    ///
    /// Lines are delimited by `\n` or `\r\n`. The delimiter is not included
    /// in the returned strings.
    public var lines: AsyncLineSequence {
        AsyncLineSequence(bytes: self)
    }
}

/// An async sequence that yields lines from a byte stream.
public struct AsyncLineSequence: AsyncSequence, Sendable {
    public typealias Element = String

    private let bytes: URLSessionAsyncBytes

    init(bytes: URLSessionAsyncBytes) {
        self.bytes = bytes
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bytesIterator: bytes.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var bytesIterator: URLSessionAsyncBytes.AsyncIterator
        var buffer: [UInt8] = []
        var finished = false

        public mutating func next() async throws -> String? {
            if finished { return nil }

            while true {
                // Check if we have a complete line in the buffer
                if let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    var lineEnd = newlineIndex
                    // Handle \r\n
                    if lineEnd > 0 && buffer[lineEnd - 1] == UInt8(ascii: "\r") {
                        lineEnd -= 1
                    }
                    let lineBytes = Array(buffer[..<lineEnd])
                    buffer.removeFirst(newlineIndex + 1)
                    return String(decoding: lineBytes, as: UTF8.self)
                }

                // Read more bytes
                guard let byte = try await bytesIterator.next() else {
                    // End of stream - return remaining buffer if non-empty
                    finished = true
                    if buffer.isEmpty {
                        return nil
                    }
                    // Handle trailing \r
                    if buffer.last == UInt8(ascii: "\r") {
                        buffer.removeLast()
                    }
                    let remaining = String(decoding: buffer, as: UTF8.self)
                    buffer.removeAll()
                    return remaining.isEmpty ? nil : remaining
                }

                buffer.append(byte)
            }
        }
    }
}

/// Delegate for streaming HTTP response data on Linux.
///
/// This class buffers incoming data and feeds it to an AsyncThrowingStream
/// for consumption by async/await code.
final class StreamingDataDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<UInt8, Error>.Continuation
    private let responseContinuation: CheckedContinuation<URLResponse, Error>
    private var hasReceivedResponse = false
    private let lock = NSLock()

    init(
        continuation: AsyncThrowingStream<UInt8, Error>.Continuation,
        responseContinuation: CheckedContinuation<URLResponse, Error>
    ) {
        self.continuation = continuation
        self.responseContinuation = responseContinuation
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        if !hasReceivedResponse {
            hasReceivedResponse = true
            responseContinuation.resume(returning: response)
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        for byte in data {
            continuation.yield(byte)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let hadResponse = hasReceivedResponse
        if !hadResponse {
            hasReceivedResponse = true
        }
        lock.unlock()

        if let error = error {
            if !hadResponse {
                responseContinuation.resume(throwing: error)
            }
            continuation.finish(throwing: error)
        } else {
            if !hadResponse {
                // Edge case: completed without receiving response
                responseContinuation.resume(throwing: URLError(.badServerResponse))
            }
            continuation.finish()
        }
    }
}

extension URLSession {
    /// Streams bytes from a URL request asynchronously (Linux polyfill).
    ///
    /// This method provides Linux compatibility for the Apple-only
    /// `URLSession.bytes(for:)` API. It uses a delegate-based approach
    /// to stream response data as it arrives.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: A tuple containing an async byte stream and the URL response.
    /// - Throws: `URLError` if the request fails.
    public func asyncBytes(for request: URLRequest) async throws -> (URLSessionAsyncBytes, URLResponse) {
        // Create a dedicated session with delegate for streaming
        var streamContinuation: AsyncThrowingStream<UInt8, Error>.Continuation!

        let byteStream = AsyncThrowingStream<UInt8, Error> { continuation in
            streamContinuation = continuation
        }

        let response: URLResponse = try await withCheckedThrowingContinuation { responseContinuation in
            let delegate = StreamingDataDelegate(
                continuation: streamContinuation,
                responseContinuation: responseContinuation
            )

            let streamingSession = URLSession(
                configuration: self.configuration,
                delegate: delegate,
                delegateQueue: nil
            )

            let task = streamingSession.dataTask(with: request)

            streamContinuation.onTermination = { @Sendable _ in
                task.cancel()
                streamingSession.invalidateAndCancel()
            }

            task.resume()
        }

        return (URLSessionAsyncBytes(stream: byteStream), response)
    }
}

#else

// MARK: - Apple Platforms Wrapper

/// Wrapper around native URLSession.AsyncBytes for API consistency.
///
/// On Apple platforms, this provides the same interface as the Linux polyfill
/// while delegating to the native implementation.
public struct URLSessionAsyncBytes: AsyncSequence, Sendable {
    public typealias Element = UInt8

    private let nativeBytes: URLSession.AsyncBytes

    init(nativeBytes: URLSession.AsyncBytes) {
        self.nativeBytes = nativeBytes
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(nativeIterator: nativeBytes.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var nativeIterator: URLSession.AsyncBytes.AsyncIterator

        public mutating func next() async throws -> UInt8? {
            try await nativeIterator.next()
        }
    }

    /// An async sequence of lines from the byte stream.
    public var lines: AsyncLineSequence {
        AsyncLineSequence(bytes: self)
    }
}

/// An async sequence that yields lines from a byte stream (Apple platforms).
///
/// This implementation mirrors the Linux polyfill for API consistency,
/// parsing lines from raw bytes rather than wrapping the native `.lines`.
public struct AsyncLineSequence: AsyncSequence, Sendable {
    public typealias Element = String

    private let bytes: URLSessionAsyncBytes

    init(bytes: URLSessionAsyncBytes) {
        self.bytes = bytes
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(bytesIterator: bytes.makeAsyncIterator())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var bytesIterator: URLSessionAsyncBytes.AsyncIterator
        var buffer: [UInt8] = []
        var finished = false

        public mutating func next() async throws -> String? {
            if finished { return nil }

            while true {
                // Check if we have a complete line in the buffer
                if let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                    var lineEnd = newlineIndex
                    // Handle \r\n
                    if lineEnd > 0 && buffer[lineEnd - 1] == UInt8(ascii: "\r") {
                        lineEnd -= 1
                    }
                    let lineBytes = Array(buffer[..<lineEnd])
                    buffer.removeFirst(newlineIndex + 1)
                    return String(decoding: lineBytes, as: UTF8.self)
                }

                // Read more bytes
                guard let byte = try await bytesIterator.next() else {
                    // End of stream - return remaining buffer if non-empty
                    finished = true
                    if buffer.isEmpty {
                        return nil
                    }
                    // Handle trailing \r
                    if buffer.last == UInt8(ascii: "\r") {
                        buffer.removeLast()
                    }
                    let remaining = String(decoding: buffer, as: UTF8.self)
                    buffer.removeAll()
                    return remaining.isEmpty ? nil : remaining
                }

                buffer.append(byte)
            }
        }
    }
}

extension URLSession {
    /// Streams bytes from a URL request asynchronously.
    ///
    /// On Apple platforms, this wraps the native `URLSession.bytes(for:)`
    /// API for API consistency with the Linux polyfill.
    ///
    /// - Parameter request: The URL request to execute.
    /// - Returns: A tuple containing the async byte stream and the URL response.
    /// - Throws: `URLError` if the request fails.
    public func asyncBytes(for request: URLRequest) async throws -> (URLSessionAsyncBytes, URLResponse) {
        let (nativeBytes, response) = try await self.bytes(for: request)
        return (URLSessionAsyncBytes(nativeBytes: nativeBytes), response)
    }
}

#endif
