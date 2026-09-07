//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import AsyncStreaming
public import BasicContainers
internal import DequeModule
public import NIOCore

/// Request Body
///
/// Can be either a stream of ByteBuffers or a single ByteBuffer
public final class RequestBody {
    @usableFromInline
    package enum _Backing: ~Copyable {
        case byteBuffer(ByteBuffer)
        case asyncReader(any (RequestAsyncReader & ~Copyable))
        case consumed

        mutating func consumeReader() -> any (RequestAsyncReader & ~Copyable) {
            switch consume self {
            case .byteBuffer:
                // TODO: Return a reader here
                fatalError("Cannot pass buffer as reader")
            case .asyncReader(let reader):
                self = .consumed
                return reader
            case .consumed:
                fatalError("Cannot consume reader twice")
            }
        }
    }

    @usableFromInline
    internal var _backing: _Backing

    @usableFromInline
    package init(_ backing: consuming _Backing) {
        self._backing = backing
    }

    public func consumeBody() -> any (RequestAsyncReader & ~Copyable) {
        self._backing.consumeReader()
    }
}

extension RequestBody {
    public typealias ReadElement = BaseRequestAsyncReader.ReadElement
    public typealias Buffer = BaseRequestAsyncReader.Buffer
    public typealias FinalElement = BaseRequestAsyncReader.FinalElement
    public typealias ReadFailure = BaseRequestAsyncReader.ReadFailure

    nonisolated(nonsending) public func read<Return: ~Copyable, Failure: Error>(
        body: nonisolated(nonsending) (inout Buffer, consuming FinalElement?) async throws(Failure) -> Return
    ) async throws(EitherError<ReadFailure, Failure>) -> Return {
        var reader = self._backing.consumeReader()
        return try await reader.read(body: body)
    }
}

extension RequestBody {
    public func collect(upTo maxSize: Int) async throws -> ByteBuffer {
        let reader = self._backing.consumeReader()
        return try await reader.collect(upTo: maxSize)
    }
}

extension AsyncReader where Self: ~Copyable, Buffer == UniqueArray<UInt8> {
    consuming func collect(upTo: Int) async throws -> ByteBuffer {
        var reader = self
        var finalElement: FinalElement? = nil
        var byteBuffer = ByteBuffer()
        while finalElement == nil {
            try await reader.read { (buffer, final) -> Void in
                //buffer.consumeAll()
                byteBuffer.writeBytes(buffer.span.bytes)
                if let final {
                    finalElement = final
                }
            }
        }
        // The force-unwrap is safe since final element must be set at this point
        return byteBuffer
    }
}
