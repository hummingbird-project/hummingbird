//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes

/// protocol for encoders generating a Response
public protocol ResponseEncoder {
    /// Encode value returned by handler to ``HummingbirdCore/Response`
    ///
    /// - Parameters:
    ///   - value: value to encode
    ///   - request: request that generated this value
    ///   - context: Request context
    func encode(_ value: some Encodable, from request: Request, context: some RequestContext) throws -> Response
}

/// protocol for decoder deserializing from a Request body
public protocol RequestDecoder {
    /// Decode Swift object from ``HummingbirdCore/Request``
    /// - Parameters:
    ///   - type: type to decode to
    ///   - request: request
    ///   - context: Request context
    func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T
}
