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

import HummingbirdCore

/// Protocol for encodable object that can generate a response. The router will encode
/// the response using the encoder stored in `Application.encoder`.
public protocol ResponseEncodable: Encodable, ResponseGenerator {}

/// Protocol for codable object that can generate a response
public protocol ResponseCodable: ResponseEncodable, Decodable {}

/// Extend ResponseEncodable to conform to ResponseGenerator
extension ResponseEncodable {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}

/// Extend Array to conform to ResponseGenerator
extension Array: ResponseGenerator where Element: Encodable {}

/// Extend Array to conform to ResponseEncodable
extension Array: ResponseEncodable where Element: Encodable {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}

/// Extend Dictionary to conform to ResponseGenerator
extension Dictionary: ResponseGenerator where Key: Encodable, Value: Encodable {}

/// Extend Array to conform to ResponseEncodable
extension Dictionary: ResponseEncodable where Key: Encodable, Value: Encodable {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        return try context.responseEncoder.encode(self, from: request, context: context)
    }
}
