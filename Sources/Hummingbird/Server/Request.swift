//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2022 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Atomics
import HummingbirdCore
import Logging
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1

/// Holds all the values required to process a request
public struct HBRequest: Sendable {
    // MARK: Member variables

    /// URI path
    public let uri: HBURL
    /// HTTP head
    public let head: HTTPRequestHead
    /// Body of HTTP request
    public var body: HBRequestBody
    /// HTTP version
    public var version: HTTPVersion { self.head.version }
    /// Request HTTP method
    public var method: HTTPMethod { self.head.method }
    /// Request HTTP headers
    public var headers: HTTPHeaders { self.head.headers }

    // MARK: Initialization

    /// Create new HBRequest
    /// - Parameters:
    ///   - head: HTTP head
    ///   - body: HTTP body
    ///   - id: Unique RequestID
    public init(
        head: HTTPRequestHead,
        body: HBRequestBody
    ) {
        self.uri = .init(head.uri)
        self.head = head
        self.body = body
    }

    // MARK: Methods

    /// Decode request using decoder stored at `HBApplication.decoder`.
    /// - Parameter type: Type you want to decode to
    public func decode<Type: Decodable>(as type: Type.Type, using context: some HBBaseRequestContext) async throws -> Type {
        do {
            return try await context.applicationContext.decoder.decode(type, from: self, context: context)
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

extension HBRequest: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), version: \(self.version), method: \(self.method), headers: \(self.headers), body: \(self.body)"
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

private extension Array where Element == CodingKey {
    /// returns a path key using a dot character as a separator
    var pathKeyValue: String {
        map(\.pathKeyValue).joined(separator: ".")
    }
}
