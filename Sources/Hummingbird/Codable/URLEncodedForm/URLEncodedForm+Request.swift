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

extension URLEncodedFormEncoder: ResponseEncoder {
    /// Extend URLEncodedFormEncoder to support encoding `Response`'s. Sets body and header values
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
    public func encode(_ value: some Encodable, from request: Request, context: some RequestContext) throws -> Response {
        let string = try self.encode(value)
        let buffer = context.allocator.buffer(string: string)
        return Response(
            status: .ok,
            headers: .defaultHummingbirdHeaders(
                contentType: "application/x-www-form-urlencoded",
                contentLength: buffer.readableBytes
            ),
            body: .init(byteBuffer: buffer)
        )
    }
}

extension URLEncodedFormDecoder: RequestDecoder {
    /// Extend URLEncodedFormDecoder to decode from `Request`.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    public func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T {
        let buffer = try await request.body.collect(upTo: context.maxUploadSize)
        let string = String(buffer: buffer)
        return try self.decode(T.self, from: string)
    }
}
