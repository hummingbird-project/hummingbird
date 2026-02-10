//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

@available(macOS 13, iOS 16, tvOS 16, *)
extension URLEncodedFormEncoder: ResponseEncoder {
    /// Extend URLEncodedFormEncoder to support generating a ``HummingbirdCore/Response``. Sets body and header values
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
    ///   - context: Request context
    public func encode(_ value: some Encodable, from request: Request, context: some RequestContext) throws -> Response {
        let string = try self.encode(value)
        let buffer = ByteBuffer(string: string)
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

@available(macOS 13, iOS 16, tvOS 16, *)
extension URLEncodedFormDecoder: RequestDecoder {
    /// Extend URLEncodedFormDecoder to decode from ``HummingbirdCore/Request``.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    ///   - context: Request context
    public func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T {
        let buffer = try await request.body.collect(upTo: context.maxUploadSize)
        let string = String(buffer: buffer)
        return try self.decode(T.self, from: string)
    }
}
