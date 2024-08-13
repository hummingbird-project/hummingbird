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

/// ResponseWriter that writes directly to AsyncChannel
public struct ResponseWriter {
    @usableFromInline
    let outbound: NIOAsyncChannelOutboundWriter<HTTPResponsePart>

    ///  Write single response part
    /// - Parameter part: response part
    @inlinable
    public func write(_ part: HTTPResponsePart) async throws {
        try await self.outbound.write(part)
    }

    ///  Write sequence of response parts
    /// - Parameter parts: response parts sequence
    @inlinable
    public func write(_ parts: some Sequence<HTTPResponsePart>) async throws {
        for part in parts {
            try await self.outbound.write(part)
        }
    }

    ///  Write AsyncSequence of response parts
    /// - Parameter parts: response parts AsyncSequence
    @inlinable
    public func write<Parts: AsyncSequence>(_ parts: Parts) async throws where Parts.Element == HTTPResponsePart {
        for try await part in parts {
            try await self.outbound.write(part)
        }
    }
}
