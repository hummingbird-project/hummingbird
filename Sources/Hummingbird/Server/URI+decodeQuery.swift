//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public import HummingbirdCore
import Logging

extension URI {
    /// Decode request query using ``Hummingbird/URLEncodedFormDecoder``.
    /// - Parameters
    ///   - type: Type you want to decode to
    ///   - context: Request context
    public func decodeQuery<Type: Decodable>(as type: Type.Type = Type.self, context: some RequestContext) throws -> Type {
        do {
            return try URLEncodedFormDecoder().decode(Type.self, from: self.query ?? "")
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
        } catch let error as any HTTPResponseError {
            context.logger.debug("Decode Error: \(error)")
            throw error
        }
    }
}
