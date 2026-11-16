//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import HTTPTypes
import HummingbirdCore

/// protocol for encoders generating a Response
@available(hummingbird 3.0, *)
public protocol ResponseEncoder {
    /// Encode value returned by handler to ``HummingbirdCore/Response`
    ///
    /// - Parameters:
    ///   - value: value to encode
    ///   - request: request that generated this value
    ///   - context: Request context
    func sendEncoded(
        _ value: some Encodable,
        from request: Request,
        writer: consuming some (ResponseWriter & ~Copyable),
        context: some RequestContext
    ) async throws
}

/// protocol for decoder deserializing from a Request body
@available(hummingbird 3.0, *)
public protocol RequestDecoder {
    /// Decode Swift object from ``HummingbirdCore/Request``
    /// - Parameters:
    ///   - type: type to decode to
    ///   - request: request
    ///   - context: Request context
    func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T
}
