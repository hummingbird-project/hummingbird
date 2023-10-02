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

/// protocol for encoders generating a Response
public protocol HBResponseEncoder: Sendable {
    /// Encode value returned by handler to request
    ///
    /// - Parameters:
    ///   - value: value to encode
    ///   - request: request that generated this value
    func encode<T: Encodable>(_ value: T, from request: HBRequest, context: HBRequestContext) throws -> HBResponse
}

/// protocol for decoder deserializing from a Request body
public protocol HBRequestDecoder: Sendable {
    /// Decode type from request
    /// - Parameters:
    ///   - type: type to decode to
    ///   - request: request
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest, context: HBRequestContext) throws -> T
}

/// Default encoder. Outputs request with the swift string description of object
struct NullEncoder: HBResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: HBRequest, context: HBRequestContext) throws -> HBResponse {
        return HBResponse(
            status: .ok,
            headers: ["content-type": "text/plain; charset=utf-8"],
            body: .byteBuffer(context.allocator.buffer(string: "\(value)"))
        )
    }
}

/// Default decoder. there is no default decoder path so this generates an error
struct NullDecoder: HBRequestDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: HBRequest, context: HBRequestContext) throws -> T {
        preconditionFailure("HBApplication.decoder has not been set")
    }
}
