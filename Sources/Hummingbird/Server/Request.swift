//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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

    /// Decode request using decoder stored at ``Hummingbird/RequestContext/requestDecoder``.
    /// - Parameters
    ///   - type: Type you want to decode to
    ///   - context: Request context
    public func decode<Type: Decodable>(as type: Type.Type, context: some RequestContext) async throws -> Type {
        do {
            return try await context.requestDecoder.decode(type, from: self, context: context)
        } catch DecodingError.dataCorrupted(let context) {
            let message = "The given data was not valid input: \(context.debugDescription)"
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

extension Request {
    /// Conditional request which will only be processed if the eTag supplied is not in the
    /// `If-None-Match` request header.
    ///
    /// For GET and HEAD methods, to update a cached entity that has an associated ETag.
    ///
    /// - Parameters:
    ///   - headers: Headers to add to response when condition fails
    ///   - eTag: ETag for this responses content
    ///   - context: Request context
    ///   - process: Closure to run if eTag is not in the `If-None-Match` header
    /// - Returns: Response
    public func ifNoneMatch(
        headers: HTTPFields = [:],
        eTag: String,
        context: some RequestContext,
        process: () async throws -> some ResponseGenerator
    ) async throws -> Response {
        var headers = headers
        headers[.eTag] = eTag
        let ifNoneMatch = self.headers[values: .ifNoneMatch]
        if ifNoneMatch.count > 0 {
            if ifNoneMatch.contains(eTag) {
                // Response status based on whether this is a read-only request ie GET or HEAD
                let status: HTTPResponse.Status =
                    if self.method == .get || self.method == .head {
                        .notModified
                    } else {
                        .preconditionFailed
                    }
                return Response(status: status, headers: headers)
            }
        }
        var response = try await process().response(from: self, context: context)
        response.headers.append(contentsOf: headers)
        return response
    }

    /// Conditional request which will only be processed if the eTag supplied is in the
    /// `If-Match` request header.
    ///
    /// - For GET and HEAD methods, used in combination with a Range header, it can guarantee
    ///   that the new ranges requested come from the same resource as the previous one.
    /// - For other methods, and in particular for PUT, If-Match can be used to prevent
    ///   the lost update problem. It can check if the modification of a resource that the
    ///   user wants to upload will not override another change that has been done since
    ///   the original resource was fetched.
    ///
    /// - Parameters:
    ///   - headers: Headers to add to response when condition fails
    ///   - eTag: ETag for this responses content
    ///   - context: Request context
    ///   - process: Closure to run if eTag is not in the `If-None-Match` header
    /// - Returns: Response
    public func ifMatch(
        headers: HTTPFields = [:],
        eTag: String,
        context: some RequestContext,
        process: () async throws -> some ResponseGenerator
    ) async throws -> Response {
        var headers = headers
        headers[.eTag] = eTag
        if !self.headers[values: .ifMatch].contains(eTag) {
            return Response(status: .preconditionFailed, headers: headers)
        }
        var response = try await process().response(from: self, context: context)
        response.headers.append(contentsOf: headers)
        return response
    }

    /// Conditional request which will only be processed if the modification date supplied is after
    /// the date in the `If-Modified-Since` request header.
    ///
    /// The most common use case is to update a cached entity that has no associated ETag.
    ///
    /// - Parameters:
    ///   - headers: Headers to add to response when condition fails
    ///   - modificationDate: Modification date for this responses content
    ///   - context: Request context
    ///   - process: Closure to run if eTag is not in the `If-None-Match` header
    /// - Returns: Response
    public func ifModifiedSince(
        headers: HTTPFields = [:],
        modificationDate: Date,
        context: some RequestContext,
        process: () async throws -> some ResponseGenerator
    ) async throws -> Response {
        var headers = headers
        headers[.lastModified] = modificationDate.httpHeader
        // `If-Modified-Since` headers are only applied to GET or HEAD requests
        if self.method == .get || self.method == .head {
            if let ifModifiedSinceHeader = self.headers[.ifModifiedSince] {
                if let ifModifiedSinceDate = Date(httpHeader: ifModifiedSinceHeader) {
                    // round modification date of file down to seconds for comparison
                    let modificationDateTimeInterval = modificationDate.timeIntervalSince1970.rounded(.down)
                    let ifModifiedSinceDateTimeInterval = ifModifiedSinceDate.timeIntervalSince1970
                    if modificationDateTimeInterval <= ifModifiedSinceDateTimeInterval {
                        return Response(status: .notModified, headers: headers)
                    }
                }
            }
        }
        var response = try await process().response(from: self, context: context)
        response.headers.append(contentsOf: headers)
        return response
    }

    /// Conditional request which will only be processed if the modification date supplied is before
    /// the date in the `If-Unmodified-Since` request header.
    ///
    /// In conjunction with non-safe methods like POST, this header can be used to implement an
    /// optimistic concurrency control, as is done by some wikis: revision are rejected if the
    /// stored document has been modified since the original was retrieved, avoiding conflicts.
    ///
    /// - Parameters:
    ///   - headers: Headers to add to response when condition fails
    ///   - modificationDate: Modification date for this responses content
    ///   - context: Request context
    ///   - process: Closure to run if eTag is not in the `If-None-Match` header
    /// - Returns: Response
    public func ifUnmodifiedSince(
        headers: HTTPFields = [:],
        modificationDate: Date,
        context: some RequestContext,
        process: () async throws -> some ResponseGenerator
    ) async throws -> Response {
        var headers = headers
        headers[.lastModified] = modificationDate.httpHeader
        if let ifUnmodifiedSinceHeader = self.headers[.ifUnmodifiedSince] {
            if let ifUnmodifiedSinceDate = Date(httpHeader: ifUnmodifiedSinceHeader) {
                // round modification date of file down to seconds for comparison
                let modificationDateTimeInterval = modificationDate.timeIntervalSince1970.rounded(.down)
                let ifUnmodifiedSinceDateTimeInterval = ifUnmodifiedSinceDate.timeIntervalSince1970
                if modificationDateTimeInterval > ifUnmodifiedSinceDateTimeInterval {
                    return Response(status: .preconditionFailed, headers: headers)
                }
            }
        }
        var response = try await process().response(from: self, context: context)
        response.headers.append(contentsOf: headers)
        return response
    }
}

extension CodingKey {
    /// returns a coding key as a path key string
    var pathKeyValue: String {
        if let value = intValue {
            return String(value)
        }
        return stringValue
    }
}

extension [CodingKey] {
    /// returns a path key using a dot character as a separator
    var pathKeyValue: String {
        map(\.pathKeyValue).joined(separator: ".")
    }
}
