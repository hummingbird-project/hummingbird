//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//
import BasicContainers
import HTTPAPIs
import HummingbirdCore

@available(hummingbird 3.0, *)
extension URLEncodedFormEncoder: ResponseEncoder {
    /// Extend URLEncodedFormEncoder to support writing a HTTP response using a ResponseWriter
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
    ///   - writer: Response writer to write responses to underlying transport
    ///   - context: Request context
    public func sendEncoded(
        _ value: some Encodable,
        from request: Request,
        writer: consuming some (ResponseWriter & ~Copyable),
        context: some RequestContext
    ) async throws {
        let string = try self.encode(value)
        var buffer = UniqueArray(copying: string.utf8)
        try await writer.sendAndFinish(
            .init(
                status: .ok,
                headerFields: .defaultHummingbirdHeaders(
                    contentType: "application/x-www-form-urlencoded",
                    contentLength: buffer.count
                )
            ),
            buffer: &buffer
        )
    }
}

@available(hummingbird 3.0, *)
extension URLEncodedFormDecoder: RequestDecoder {
    /// Extend URLEncodedFormDecoder to decode from ``HummingbirdCore/Request``.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    ///   - context: Request context
    public func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T {
        let buffer = try await request.body.collect(upTo: context.maxUploadSize)
        return try buffer.span.withUnsafeBytes { bytes in
            let string = String(decoding: bytes, as: UTF8.self)
            return try self.decode(T.self, from: string)
        }
    }
}
