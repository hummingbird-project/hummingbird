//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import ContainersPreview
public import HTTPAPIs
public import HTTPTypes

@available(hummingbird 3.0, *)
public struct TransformingBodyResponseWriter<Parent: ResponseWriter & ~Copyable, Writer: ResponseBodyAsyncWriter & ~Copyable>: ResponseWriter,
    ~Copyable
{

    @inlinable
    package init(_ parentWriter: consuming Parent, _ transform: @escaping (consuming Parent.Writer) async throws -> Writer) {
        self.parentWriter = consume parentWriter
        self.transformWriter = transform
    }

    @inlinable
    public mutating func sendInformational(_ response: HTTPResponse) async throws {
        try await self.parentWriter.sendInformational(response)
    }

    @inlinable
    public consuming func send(_ response: HTTPResponse) async throws -> Writer {
        let writer = try await self.parentWriter.send(response)
        return try await transformWriter(writer)
    }

    @inlinable
    public consuming func sendAndFinish<Buffer>(_ response: HTTPResponse, buffer: inout Buffer, trailer: HTTPFields?) async throws
    where Buffer: RangeReplaceableContainer, Buffer.Element == UInt8, Buffer: ~Copyable {
        let writer = try await self.parentWriter.send(response)
        let transformedWriter = try await transformWriter(writer)
        try await transformedWriter.finish(buffer: &buffer, finalElement: trailer)
    }

    @usableFromInline
    var parentWriter: Parent
    @usableFromInline
    let transformWriter: nonisolated(nonsending) (consuming Parent.Writer) async throws -> Writer
}
