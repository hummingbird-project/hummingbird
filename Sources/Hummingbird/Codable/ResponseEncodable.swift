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
/// the response using the encoder stored in `HBApplication.encoder`.
public protocol HBResponseEncodable: Encodable, HBResponseGenerator {}

/// Protocol for codable object that can generate a response
public protocol HBResponseCodable: HBResponseEncodable, Decodable {}

/// Extend ResponseEncodable to conform to ResponseGenerator
extension HBResponseEncodable {
    public func response(from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse {
        return try context.applicationContext.encoder.encode(self, from: request, context: context)
    }
}

/// Extend Array to conform to HBResponseGenerator
extension Array: HBResponseGenerator where Element: Encodable {}

/// Extend Array to conform to HBResponseEncodable
extension Array: HBResponseEncodable where Element: Encodable {
    public func response(from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse {
        return try context.applicationContext.encoder.encode(self, from: request, context: context)
    }
}

/// Extend Dictionary to conform to HBResponseGenerator
extension Dictionary: HBResponseGenerator where Key: Encodable, Value: Encodable {}

/// Extend Array to conform to HBResponseEncodable
extension Dictionary: HBResponseEncodable where Key: Encodable, Value: Encodable {
    public func response(from request: HBRequest, context: some HBBaseRequestContext) throws -> HBResponse {
        return try context.applicationContext.encoder.encode(self, from: request, context: context)
    }
}
