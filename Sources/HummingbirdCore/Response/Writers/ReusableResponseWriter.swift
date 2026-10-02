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

/// Wrapper for existential ResponseWriter
@available(hummingbird 3.0, *)
public final class ReusableResponseWriter<Writer: ResponseWriter & ~Copyable>: ResponseWriter {
    public init(writer: consuming Writer) {
        self.writer = consume writer
    }

    @inlinable
    public func sendInformational(_ response: HTTPResponse) async throws {
        try await self.writer!.sendInformational(response)
    }

    @inlinable
    public consuming func send(_ response: HTTPResponse) async throws -> AnyResponseBodyAsyncWriter {
        let writer = self.writer.take()!
        return try await .init(writer.send(response))
    }

    @inlinable
    public consuming func sendAndFinish<Buffer>(_ response: HTTPResponse, buffer: inout Buffer, trailer: HTTPFields?) async throws
    where Buffer: RangeReplaceableContainer, Buffer.Element == UInt8, Buffer: ~Copyable {
        let writer = self.writer.take()!
        try await writer.sendAndFinish(response, buffer: &buffer, trailer: trailer)
    }

    public consuming func take() -> Writer? {
        self.writer.take()
    }

    public var writer: Writer?
}
