//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore

extension Request {
    /// Collapse body into one ByteBuffer.
    ///
    /// This will store the collated ByteBuffer back into the request so is a mutating method. If
    /// you don't need to store the collated ByteBuffer on the request then use
    /// `request.body.collate(maxSize:)`.
    ///
    /// - Parameter context: Request context
    /// - Returns: Collated body
    @_documentation(visibility: internal) @available(*, unavailable, message: "Use Request.collectBody(upTo:) instead")
    public mutating func collateBody(context: some RequestContext) async throws -> ByteBuffer {
        try await self.collectBody(upTo: context.maxUploadSize)
    }

    /// Decode request using decoder stored at `Application.decoder`.
    /// - Parameters
    ///   - type: Type you want to decode to
    ///   - context: Request context
    public func decode<Type: Decodable>(as type: Type.Type, context: some RequestContext) async throws -> Type {
        do {
            return try await context.requestDecoder.decode(type, from: self, context: context)
        } catch DecodingError.dataCorrupted(_) {
            let message = "The given data was not valid input."
            throw HTTPError(.badRequest, message: message)
        } catch DecodingError.keyNotFound(let key, _) {
            let path = key.pathKeyValue
            let message = "Coding key `\(path)` not found."
            throw HTTPError(.badRequest, message: message)
        } catch DecodingError.valueNotFound(_, let context) {
            let path = context.codingPath.pathKeyValue
            let message = "Value not found for `\(path)` key."
            throw HTTPError(.badRequest, message: message)
        } catch DecodingError.typeMismatch(let type, let context) {
            let path = context.codingPath.pathKeyValue
            let message = "Type mismatch for `\(path)` key, expected `\(type)` type."
            throw HTTPError(.badRequest, message: message)
        } catch let error as HTTPResponseError {
            context.logger.debug("Decode Error: \(error)")
            throw error
        }
    }
}

private extension CodingKey {
    /// returns a coding key as a path key string
    var pathKeyValue: String {
        if let value = intValue {
            return String(value)
        }
        return stringValue
    }
}

private extension Array<CodingKey> {
    /// returns a path key using a dot character as a separator
    var pathKeyValue: String {
        map(\.pathKeyValue).joined(separator: ".")
    }
}
