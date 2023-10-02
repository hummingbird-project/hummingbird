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

import NIOHTTP1

/// Object that can generate a `Response`.
///
/// This is used by `Router` to convert handler return values into a `HBResponse`.
public protocol HBResponseGenerator {
    /// Generate response based on the request this object came from
    func response(from request: HBRequest, context: HBRequestContext) throws -> HBResponse
}

extension HBResponseGenerator {
    /// Generate reponse based on the request this object came from and apply request patches
    func patchedResponse(from request: HBRequest, context: HBRequestContext) throws -> HBResponse {
        var r = try response(from: request, context: context)
        return r.apply(patch: request.optionalResponse)
    }
}

/// Extend Response to conform to ResponseGenerator
extension HBResponse: HBResponseGenerator {
    /// Return self as the response
    public func response(from request: HBRequest, context: HBRequestContext) -> HBResponse { self }
}

/// Extend String to conform to ResponseGenerator
extension String: HBResponseGenerator {
    /// Generate response holding string
    public func response(from request: HBRequest, context: HBRequestContext) -> HBResponse {
        let buffer = context.allocator.buffer(string: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .byteBuffer(buffer))
    }
}

/// Extend String to conform to ResponseGenerator
extension Substring: HBResponseGenerator {
    /// Generate response holding string
    public func response(from request: HBRequest, context: HBRequestContext) -> HBResponse {
        let buffer = context.allocator.buffer(substring: self)
        return HBResponse(status: .ok, headers: ["content-type": "text/plain; charset=utf-8"], body: .byteBuffer(buffer))
    }
}

/// Extend ByteBuffer to conform to ResponseGenerator
extension ByteBuffer: HBResponseGenerator {
    /// Generate response holding bytebuffer
    public func response(from request: HBRequest, context: HBRequestContext) -> HBResponse {
        HBResponse(status: .ok, headers: ["content-type": "application/octet-stream"], body: .byteBuffer(self))
    }
}

/// Extend HTTPResponseStatus to conform to ResponseGenerator
extension HTTPResponseStatus: HBResponseGenerator {
    /// Generate response with this response status code
    public func response(from request: HBRequest, context: HBRequestContext) -> HBResponse {
        HBResponse(status: self, headers: [:], body: .empty)
    }
}

/// Extend Optional to conform to HBResponseGenerator
extension Optional: HBResponseGenerator where Wrapped: HBResponseGenerator {
    public func response(from request: HBRequest, context: HBRequestContext) throws -> HBResponse {
        switch self {
        case .some(let wrapped):
            return try wrapped.response(from: request, context: context)
        case .none:
            return HBResponse(status: .noContent, headers: [:], body: .empty)
        }
    }
}
