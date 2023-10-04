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

/// Holds all the values required to process a request
public struct HBRequest: Sendable, HBSendableExtensible {
    // MARK: Member variables

    /// URI path
    public var uri: HBURL { self._internal.uri }
    /// HTTP version
    public var version: HTTPVersion { self._internal.version }
    /// Request HTTP method
    public var method: HTTPMethod { self._internal.method }
    /// Request HTTP headers
    public var headers: HTTPHeaders { self._internal.headers }
    /// Body of HTTP request
    public var body: HBRequestBody
    /// Request extensions
    public var extensions: HBSendableExtensions<HBRequest>

    /// Parameters extracted during processing of request URI. These are available to you inside the route handler
    public var parameters: HBParameters {
        @inlinable get {
            self.extensions.get(\.parameters) ?? .init()
        }
        @inlinable set { self.extensions.set(\.parameters, value: newValue) }
    }

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
        self._internal = .init(
            uri: .init(head.uri),
            version: head.version,
            method: head.method,
            headers: head.headers
        )
        self.body = body
        self.extensions = .init()
    }

    // MARK: Methods

    /// Decode request using decoder stored at `HBApplication.decoder`.
    /// - Parameter type: Type you want to decode to
    public func decode<Type: Decodable>(as type: Type.Type, using context: any HBRequestContext) throws -> Type {
        do {
            return try context.applicationContext.decoder.decode(type, from: self, context: context)
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

    /// Store all the read-only values of the request in a class to avoid copying them
    /// everytime we pass the `HBRequest` struct about
    final class _Internal: Sendable {
        internal init(uri: HBURL, version: HTTPVersion, method: HTTPMethod, headers: HTTPHeaders) {
            self.uri = uri
            self.version = version
            self.method = method
            self.headers = headers
        }

        /// URI path
        let uri: HBURL
        /// HTTP version
        let version: HTTPVersion
        /// Request HTTP method
        let method: HTTPMethod
        /// Request HTTP headers
        let headers: HTTPHeaders
    }

    private var _internal: _Internal
}

extension Logger {
    /// Create new Logger with additional metadata value
    /// - Parameters:
    ///   - metadataKey: Metadata key
    ///   - value: Metadata value
    /// - Returns: Logger
    func with(metadataKey: String, value: MetadataValue) -> Logger {
        var logger = self
        logger[metadataKey: metadataKey] = value
        return logger
    }
}

extension HBRequest: CustomStringConvertible {
    public var description: String {
        "uri: \(self.uri), version: \(self.version), method: \(self.method), headers: \(self.headers), body: \(self.body)"
    }
}
