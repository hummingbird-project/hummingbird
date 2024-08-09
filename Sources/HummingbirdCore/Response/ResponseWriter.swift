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

import NIOCore
import NIOHTTPTypes

public struct ResponseWriter {
    @usableFromInline
    let outbound: NIOAsyncChannelOutboundWriter<HTTPResponsePart>

    @inlinable
    public func write(_ part: HTTPResponsePart) async throws {
        try await self.outbound.write(part)
    }

    @inlinable
    public func write(_ parts: some Sequence<HTTPResponsePart>) async throws {
        for part in parts {
            try await self.outbound.write(part)
        }
    }

    @inlinable
    public func write<AsyncSeq: AsyncSequence>(_ parts: AsyncSeq) async throws where AsyncSeq.Element == HTTPResponsePart {
        for try await part in parts {
            try await self.outbound.write(part)
        }
    }
}
