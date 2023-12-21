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

import HTTPTypes

/// protocol for encoders generating a Response
public protocol HBResponseEncoder: Sendable {
    /// Encode value returned by handler to request
    ///
    /// - Parameters:
    ///   - value: value to encode
    ///   - request: request that generated this value
    func encode(_ value: some Encodable, from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse
}

/// protocol for decoder deserializing from a Request body
public protocol HBRequestDecoder: Sendable {
    /// Decode type from request
    /// - Parameters:
    ///   - type: type to decode to
    ///   - request: request
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest, context: some HBBaseRequestContext) async throws -> T
}

/// Default encoder. Outputs request with the swift string description of object
public struct NullEncoder: HBResponseEncoder {
    public init() {}
    public func encode(_ value: some Encodable, from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse {
        return HBResponse(
            status: .ok,
            headers: [.contentType: "text/plain; charset=utf-8"],
            body: .init(byteBuffer: context.allocator.buffer(string: "\(value)"))
        )
    }
}

/// Default decoder. there is no default decoder path so this generates an error
public struct NullDecoder: HBRequestDecoder {
    public init() {}
    public func decode<T: Decodable>(_ type: T.Type, from request: HBRequest, context: some HBBaseRequestContext) throws -> T {
        preconditionFailure("Request context decoder has not been set")
    }
}
