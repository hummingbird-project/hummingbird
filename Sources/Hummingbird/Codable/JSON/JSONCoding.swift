//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct Foundation.Date
@_exported import class Foundation.JSONDecoder
@_exported import class Foundation.JSONEncoder
import NIOFoundationCompat

extension JSONEncoder: ResponseEncoder {
    /// Extend JSONEncoder to support encoding `Response`'s. Sets body and header values
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
    public func encode(_ value: some Encodable, from request: Request, context: some BaseRequestContext) throws -> Response {
        var buffer = context.allocator.buffer(capacity: 0)
        let data = try self.encode(value)
        buffer.writeBytes(data)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json; charset=utf-8"],
            body: .init(byteBuffer: buffer)
        )
    }
}

extension JSONDecoder: RequestDecoder {
    /// Extend JSONDecoder to decode from `Request`.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    public func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some BaseRequestContext) async throws -> T {
        let buffer = try await request.body.collect(upTo: context.maxUploadSize)
        return try self.decode(T.self, from: buffer)
    }
}

/// `RequestDecoder` and `ResponseEncoder` both require conformance to `Sendable`. Given
/// `JSONEncoder`` and `JSONDecoder`` conform to Sendable in macOS 13+ I think I can just
/// back date the conformance to all versions of Swift, macOS we support
#if hasFeature(RetroactiveAttribute)
extension JSONEncoder: @retroactive @unchecked Sendable {}
extension JSONDecoder: @retroactive @unchecked Sendable {}
#else
extension JSONEncoder: @unchecked Sendable {}
extension JSONDecoder: @unchecked Sendable {}
#endif
