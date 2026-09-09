//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import AsyncStreaming
public import BasicContainers
public import ContainersPreview
internal import DequeModule
public import HTTPTypes

/// Request Body
///
/// Can be either a stream of ByteBuffers or a single ByteBuffer
public final class RequestBody {
    @usableFromInline
    package enum _Backing: ~Copyable {
        case asyncReader(any (RequestAsyncReader & ~Copyable))
        case consumed

        @usableFromInline
        mutating func take() -> any (RequestAsyncReader & ~Copyable) {
            switch consume self {
            case .asyncReader(let reader):
                self = .consumed
                return reader
            case .consumed:
                fatalError("Cannot consume reader twice")
            }
        }

        @usableFromInline
        mutating func optionalTake() -> (any (RequestAsyncReader & ~Copyable))? {
            switch consume self {
            case .asyncReader(let reader):
                self = .consumed
                return reader
            case .consumed:
                self = .consumed
                return nil
            }
        }
    }

    @usableFromInline
    internal var _backing: _Backing

    @usableFromInline
    package init(_ backing: consuming _Backing) {
        self._backing = backing
    }

    package init(bytes: consuming UniqueArray<UInt8>) {
        self._backing = .asyncReader(CollatedRequestAsyncReader(bytes))
    }

    /// Take request body AsyncReader from RequestBody. By doing this you are setting the
    /// request body to be consumed and it is your responsibility to ensure the reader
    /// reads the request body.
    public var reader: any (RequestAsyncReader & ~Copyable) {
        self._backing.take()
    }
}

extension RequestBody {
    public typealias ReadElement = UInt8
    public typealias Buffer = UniqueArray<UInt8>
    public typealias FinalElement = HTTPFields?
    public typealias ReadFailure = any Error

    @inlinable
    @discardableResult
    public consuming func forEachBuffer<Failure: Error>(
        body: (inout Buffer) async throws(Failure) -> Void
    ) async throws(EitherError<ReadFailure, Failure>) -> FinalElement? {
        var reader = self._backing.take()
        var final: FinalElement? = nil
        var done = false
        while !done {
            try await reader.read { (next, finalElement) throws(Failure) -> Void in
                if !next.isEmpty {
                    try await body(&next)
                }
                if let finalElement {
                    final = finalElement
                    done = true
                }
            }
        }
        return final
    }

    @inlinable
    @discardableResult
    public consuming func collect<Container: RangeReplaceableContainer<ReadElement> & ~Copyable & ~Escapable>(
        into target: inout Container
    ) async throws(EitherError<ReadFailure, AsyncReaderLeftOverElementsError>) -> FinalElement {
        let reader = self._backing.take()
        return try await reader.collect(into: &target)
    }

    @inlinable
    public consuming func pipe<Writer>(
        into writer: consuming Writer
    ) async throws(EitherError<ReadFailure, Writer.WriteFailure>)
    where
        Writer: CallerAsyncWriter & ~Copyable,
        Writer.WriteElement == ReadElement,
        Writer.FinalElement == FinalElement
    {
        let reader = self._backing.take()
        return try await reader.pipe(into: writer)
    }
}

extension RequestBody {
    @inlinable
    public func collect(upTo maxSize: Int) async throws -> UniqueArray<UInt8> {
        let reader = self._backing.take()
        do {
            return try await reader.collect(upTo: maxSize)
        } catch {
            switch error {
            case .first(let error): throw error
            case .second(let error): throw error
            }
        }
    }

    @inlinable
    public func drain() async throws {
        guard let reader = self._backing.optionalTake() else { return }
        try await reader.drain()
    }
}
