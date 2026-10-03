//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdCore

/// Protocol for encodable object that can generate a response. The router will encode
/// the response using the encoder stored in `Application.encoder`.
@available(hummingbird 3.0, *)
public protocol ResponseEncodable: Encodable, ResponseGenerator {}

/// Protocol for codable object that can generate a response
@available(hummingbird 3.0, *)
public protocol ResponseCodable: ResponseEncodable, Decodable {}

/// Extend ResponseEncodable to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension ResponseEncodable {
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        try await context.responseEncoder.sendEncoded(self, from: request, writer: writer, context: context)
    }
}

/// Extend Array to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension Array: ResponseGenerator where Element: Encodable {}

/// Extend Array to conform to ResponseEncodable
@available(hummingbird 3.0, *)
extension Array: ResponseEncodable where Element: Encodable {
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        try await context.responseEncoder.sendEncoded(self, from: request, writer: writer, context: context)
    }
}

/// Extend Dictionary to conform to ResponseGenerator
@available(hummingbird 3.0, *)
extension Dictionary: ResponseGenerator where Key: Encodable, Value: Encodable {}

/// Extend Array to conform to ResponseEncodable
@available(hummingbird 3.0, *)
extension Dictionary: ResponseEncodable where Key: Encodable, Value: Encodable {
    public func writeResponse(from request: Request, writer: consuming some ResponseWriter & ~Copyable, context: some RequestContext) async throws {
        try await context.responseEncoder.sendEncoded(self, from: request, writer: writer, context: context)
    }
}
