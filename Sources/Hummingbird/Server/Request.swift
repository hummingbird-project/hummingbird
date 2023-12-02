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

extension HBRequest {
    /// Decode request using decoder stored at `HBApplication.decoder`.
    /// - Parameter type: Type you want to decode to
    public func decode<Type: Decodable>(as type: Type.Type, using context: some HBBaseRequestContext) async throws -> Type {
        do {
            return try await context.requestDecoder.decode(type, from: self, context: context)
        } catch DecodingError.dataCorrupted(_) {
            let message = "The given data was not valid input."
            throw HBHTTPError(.badRequest, message: message)
        } catch DecodingError.keyNotFound(let key, _) {
            let path = key.pathKeyValue
            let message = "Coding key `\(path)` not found."
            throw HBHTTPError(.badRequest, message: message)
        } catch DecodingError.valueNotFound(_, let context) {
            let path = context.codingPath.pathKeyValue
            let message = "Value not found for `\(path)` key."
            throw HBHTTPError(.badRequest, message: message)
        } catch DecodingError.typeMismatch(let type, let context) {
            let path = context.codingPath.pathKeyValue
            let message = "Type mismatch for `\(path)` key, expected `\(type)` type."
            throw HBHTTPError(.badRequest, message: message)
        } catch let error as HBHTTPResponseError {
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

private extension [CodingKey] {
    /// returns a path key using a dot character as a separator
    var pathKeyValue: String {
        map(\.pathKeyValue).joined(separator: ".")
    }
}
