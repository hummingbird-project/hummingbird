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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension JSONEncoder: ResponseEncoder {
    /// Extend JSONEncoder to support encoding `Response`'s. Sets body and header values
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
    ///   - context: Request context
    public func encode(_ value: some Encodable, from request: Request, context: some RequestContext) throws -> Response {
        let data = try self.encode(value)
        let buffer = ByteBuffer(bytes: data)
        return Response(
            status: .ok,
            headers: .defaultHummingbirdHeaders(
                contentType: "application/json; charset=utf-8",
                contentLength: data.count
            ),
            body: .init(byteBuffer: buffer)
        )
    }
}

extension JSONDecoder: RequestDecoder {
    /// Extend JSONDecoder to decode from `Request`.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    ///   - context: Request context
    public func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T {
        let buffer = try await request.body.collect(upTo: context.maxUploadSize)
        let data = buffer.getData(at: buffer.readerIndex, length: buffer.readableBytes, byteTransferStrategy: .noCopy)!
        return try self.decode(T.self, from: data)
    }
}
