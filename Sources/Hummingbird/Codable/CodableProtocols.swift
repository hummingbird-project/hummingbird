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

/// Protocol for ``Encoder``s  that generate a ``Response``
public protocol ResponseEncoder {
    /// Encode value returned by handler to request
    ///
    /// - Parameters:
    ///   - value: value to encode
    ///   - request: request that generated this value
    func encode(_ value: some Encodable, from request: Request, context: some BaseRequestContext) throws -> Response
}

/// Protocol for ``Decoder``s deserializing from a ``Request``'s body
public protocol RequestDecoder {
    /// Decode type from request
    /// - Parameters:
    ///   - type: type to decode to
    ///   - request: request
    func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some BaseRequestContext) async throws -> T
}
