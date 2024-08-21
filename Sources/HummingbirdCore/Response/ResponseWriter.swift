//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HTTPTypes
import NIOCore
import NIOHTTPTypes

/// ResponseWriter that writes directly to AsyncChannel
public struct ResponseWriter {
    @usableFromInline
    let outbound: NIOAsyncChannelOutboundWriter<HTTPResponsePart>

    @inlinable
    public consuming func writeHead(_ head: HTTPResponse) async throws -> some ResponseBodyWriter {
        try await self.outbound.write(.head(head))
        return RootResponseBodyWriter(outbound: self.outbound)
    }

    @inlinable
    public consuming func writeInformationalHead(_ head: HTTPResponse) async throws {
        precondition((100..<200).contains(head.status.code), "Informational HTTP responses require a status code between 100 and 199")
        try await self.outbound.write(.head(head))
    }

    @inlinable
    public consuming func writeResponse(_ head: HTTPResponse) async throws {
        try await self.outbound.write(contentsOf: [.head(head), .end(nil)])
    }
}

/// ResponseBodyWriter that writes ByteBuffers to AsyncChannel outbound writer
@usableFromInline
struct RootResponseBodyWriter: Sendable, ResponseBodyWriter {
    typealias Out = HTTPResponsePart
    /// The components of a HTTP response from the view of a HTTP server.
    public typealias OutboundWriter = NIOAsyncChannelOutboundWriter<Out>

    let outbound: OutboundWriter

    @usableFromInline
    init(outbound: OutboundWriter) {
        self.outbound = outbound
    }

    /// Write a single ByteBuffer
    /// - Parameter buffer: single buffer to write
    @usableFromInline
    func write(_ buffer: ByteBuffer) async throws {
        try await self.outbound.write(.body(buffer))
    }

    /// Write a sequence of ByteBuffers
    /// - Parameter buffers: Sequence of buffers
    @usableFromInline
    func write(contentsOf buffers: some Sequence<ByteBuffer>) async throws {
        try await self.outbound.write(contentsOf: buffers.map { .body($0) })
    }

    /// Finish writing body
    /// - Parameter trailingHeaders: Any trailing headers you want to include at end
    @usableFromInline
    consuming func finish(_ trailingHeaders: HTTPFields?) async throws {
        try await self.outbound.write(.end(trailingHeaders))
    }
}
