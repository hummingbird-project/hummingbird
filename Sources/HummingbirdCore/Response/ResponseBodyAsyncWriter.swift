//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import BasicContainers
import ContainersPreview
public import HTTPAPIs
public import HTTPTypes

/// A `CallerAsyncWriter` for writing HTTP responses
public protocol ResponseBodyAsyncWriter: CallerAsyncWriter, ~Copyable
where WriteElement == UInt8, WriteFailure == any Error, FinalElement == HTTPFields? {
}

/// Wrapper for existential ResponseBodyAsyncWriter
public struct AnyResponseBodyAsyncWriter: ~Copyable, ResponseBodyAsyncWriter {
    @usableFromInline
    package init(_ writer: consuming (any ResponseBodyAsyncWriter & ~Copyable)) {
        self.writer = consume writer
    }

    @inlinable
    public mutating nonisolated(nonsending) func write<Buffer>(buffer: inout Buffer) async throws(any Error)
    where Buffer: RangeReplaceableContainer, UInt8 == Buffer.Element, Buffer: ~Copyable, Buffer.Element: ~Copyable {
        try await self.writer!.write(buffer: &buffer)
    }

    @inlinable
    public consuming nonisolated(nonsending) func finish<Buffer>(
        buffer: inout Buffer,
        finalElement: consuming HTTPTypes.HTTPFields? = nil
    ) async throws(any Error)
    where Buffer: RangeReplaceableContainer, UInt8 == Buffer.Element, Buffer: ~Copyable, Buffer.Element: ~Copyable {
        let writer = self.writer.take()!
        try await writer.finish(buffer: &buffer, finalElement: finalElement)
    }

    @inlinable
    public consuming nonisolated(nonsending) func finish(finalElement: consuming HTTPTypes.HTTPFields? = nil) async throws(any Error) {
        let writer = self.writer.take()!
        var empty = UniqueArray<UInt8>()
        try await writer.finish(buffer: &empty, finalElement: finalElement)
    }

    public var writer: (any ResponseBodyAsyncWriter & ~Copyable)?
}
