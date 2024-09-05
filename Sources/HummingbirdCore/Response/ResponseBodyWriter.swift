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

/// Type erasing ``ResponseBodyWriterProtocol``.
///
/// Holds a pointer to any ResponseBodyWriterProtocol.
public struct ResponseBodyWriter: ResponseBodyWriterProtocol {
    public var wrapped: any ResponseBodyWriterProtocol

    @inlinable
    public init(_ writer: some ResponseBodyWriterProtocol) {
        self.wrapped = writer
    }

    @inlinable
    public mutating func write(_ buffer: NIOCore.ByteBuffer) async throws {
        try await self.wrapped.write(buffer)
    }

    @inlinable
    public func finish(_ trailingHeaders: HTTPTypes.HTTPFields? = nil) async throws {
        try await self.wrapped.finish(trailingHeaders)
    }
}
