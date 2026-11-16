//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import BasicContainers
import HTTPAPIs
import HTTPTypes

/// Used to Box a non-copyable so it can be used in copyable struct
@usableFromInline
final class Box<Value: ~Copyable> {
    @usableFromInline
    var value: Value

    @usableFromInline
    init(value: consuming Value) {
        self.value = value
    }
}

/// Response body
public struct ResponseBody {
    @usableFromInline
    enum _Backing {
        case bytes(Box<UniqueArray<UInt8>>)
        case empty
        case closure(Int?, (consuming AnyResponseBodyAsyncWriter) async throws -> Void)
    }

    @usableFromInline
    let _backing: _Backing

    public var contentLength: Int? {
        switch _backing {
        case .bytes(let buf): return buf.value.count
        case .empty: return 0
        case .closure(let len, _): return len
        }
    }

    /// Initialise ResponseBody with closure writing body contents.
    ///
    /// When you have finished writing the response body you need to indicate you have
    /// finished by calling ``ResponseBodyWriter/finish(_:)``. At this
    /// point you can also send trailing headers by including them as a parameter in
    /// the finsh() call.
    /// ```
    /// let responseBody = ResponseBody(contentLength: contentLength) { writer in
    ///     try await writer.write(buffer)
    ///     try await writer.finish(nil)
    /// }
    /// ```
    /// - Parameters:
    ///   - contentLength: Optional length of body
    ///   - write: closure provided with `writer` type that can be used to write to response body
    public init(contentLength: Int? = nil, _ write: @escaping (consuming AnyResponseBodyAsyncWriter) async throws -> Void) {
        self._backing = .closure(contentLength, write)
    }

    /// Initialise empty ResponseBody
    public init() {
        self._backing = .empty
    }

    /// Initialise ResponseBody that contains a single ByteBuffer
    /// - Parameter byteBuffer: ByteBuffer to write
    public init(_ bytes: consuming UniqueArray<UInt8>) {
        self._backing = .bytes(.init(value: bytes))
    }

    @inlinable
    @available(hummingbird 3.0, *)
    public consuming func write(_ writer: consuming any (ResponseBodyAsyncWriter & ~Copyable)) async throws {
        let writer = AnyResponseBodyAsyncWriter(writer)
        try await write(writer)
    }

    @inlinable
    @available(hummingbird 3.0, *)
    public consuming func write(_ writer: consuming AnyResponseBodyAsyncWriter) async throws {
        switch self._backing {
        case .bytes(let buf):
            try await writer.finish(buffer: &buf.value)
        case .empty:
            try await writer.finish()
        case .closure(_, let fn):
            try await fn(writer)
        }
    }

    private init(_backing: consuming _Backing) {
        self._backing = _backing
    }
}
