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

import NIO
import NIOHTTP1

/// Object that can generate a `Response`.
///
/// This is used by `Router` to convert handler return values into a `HBResponse`.
public protocol HBResponseGenerator {
    /// Generate response based on the request this object came from
    func response(from request: HBRequest) throws -> HBResponse
}

extension HBResponseGenerator {
    /// Generate reponse based on the request this object came from and apply request patches
    func patchedResponse(from request: HBRequest) throws -> HBResponse {
        try response(from: request).apply(patch: request.optionalResponse)
    }
}

/// Extend Response to conform to ResponseGenerator
extension HBResponse: HBResponseGenerator {
    /// Return self as the response
    public func response(from request: HBRequest) -> HBResponse { self }
}

/// Extend String to conform to ResponseGenerator
extension String: HBResponseGenerator {
    /// Generate response holding string
    public func response(from request: HBRequest) -> HBResponse {
        let buffer = request.allocator.buffer(string: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .byteBuffer(buffer))
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: HBResponseGenerator {
    /// Generate response holding bytebuffer
    public func response(from request: HBRequest) -> HBResponse {
        HBResponse(status: .ok, headers: ["content-type": "application/octet-stream"], body: .byteBuffer(self))
    }
}

/// Extend HTTPResponseStatus to conform to ResponseGenerator
extension HTTPResponseStatus: HBResponseGenerator {
    /// Generate response with this response status code
    public func response(from request: HBRequest) -> HBResponse {
        HBResponse(status: self, headers: [:], body: .empty)
    }
}

/// Extend Optional to conform to HBResponseGenerator
extension Optional: HBResponseGenerator where Wrapped: HBResponseGenerator {
    public func response(from request: HBRequest) throws -> HBResponse {
        switch self {
        case .some(let wrapped):
            return try wrapped.response(from: request)
        case .none:
            throw HBHTTPError(.notFound)
        }
    }
}

/// Extend EventLoopFuture of a ResponseEncodable to conform to ResponseFutureEncodable
/*extension EventLoopFuture where Value: HBResponseGenerator {
    /// Generate `EventLoopFuture` that will be fulfilled with the response
    public func responseFuture(from request: HBRequest) -> EventLoopFuture<HBResponse> {
        return self.flatMapThrowing { try $0.response(from: request) }
    }
}*/
