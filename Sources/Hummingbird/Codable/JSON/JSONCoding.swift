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
private import NIOFoundationEssentialsCompat

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

@available(hummingbird 3.0, *)
extension JSONEncoder: ResponseEncoder {
    /// Extend JSONEncoder to support generating a ``HummingbirdCore/Response``. Sets body and header values
    /// - Parameters:
    ///   - value: Value to encode
    ///   - request: Request used to generate response
    ///   - context: Request context
    public func sendValue(
        _ value: some Encodable,
        from request: Request,
        writer: consuming some (ResponseWriter & ~Copyable),
        context: some RequestContext
    ) async throws {
        let data = try self.encode(value)
        var buffer = UniqueArray(copying: data)
        try await writer.sendAndFinish(
            .init(
                status: .ok,
                headerFields: .defaultHummingbirdHeaders(
                    contentType: "application/json; charset=utf-8",
                    contentLength: data.count
                )
            ),
            buffer: &buffer
        )
    }
}

@available(hummingbird 3.0, *)
extension JSONDecoder: RequestDecoder {
    /// Extend JSONDecoder to decode from ``HummingbirdCore/Request``.
    /// - Parameters:
    ///   - type: Type to decode
    ///   - request: Request to decode from
    ///   - context: Request context
    public func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T {
        var buffer = try await request.body.collect(upTo: context.maxUploadSize)
        var mutableSpan = buffer.mutableSpan
        return try mutableSpan.withUnsafeMutableBytes { bytes in
            let data = Data(bytesNoCopy: bytes.baseAddress!, count: bytes.count, deallocator: .none)
            return try self.decode(T.self, from: data)
        }
    }
}
