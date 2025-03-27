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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Response {
    /// Specifies the type of redirect that the client should receive.
    public enum RedirectType {
        /// `301 moved permanently`: The URL of the requested resource has been changed permanently.
        /// The new URL is given in the response.
        case permanent
        /// `302 found`: This response code means that the URI of requested resource has been changed
        /// temporarily. Further changes in the URI might be made in the future. Therefore,
        /// this same URI should be used by the client in future requests.
        case found
        /// `303 see other`: The server sent this response to direct the client to get the requested
        /// resource at another URI with a GET request.
        case normal
        /// `307 Temporary`: The server sends this response to direct the client to get the requested
        /// resource at another URI with the same method that was used in the prior request. This has
        /// the same semantics as the 302 Found HTTP response code, with the exception that the user
        /// agent must not change the HTTP method used: if a POST was used in the first request, a POST
        /// must be used in the second request.
        case temporary

        /// Associated `HTTPResponse.Status` for this redirect type.
        public var status: HTTPResponse.Status {
            switch self {
            case .permanent: return .movedPermanently
            case .found: return .found
            case .normal: return .seeOther
            case .temporary: return .temporaryRedirect
            }
        }
    }

    ///  Create a redirect response
    /// - Parameters:
    ///   - location: Location to redirect to
    ///   - type: Redirection type
    /// - Returns: Response with redirection
    public static func redirect(to location: String, type: RedirectType = .normal) -> Response {
        .init(status: type.status, headers: [.location: location])
    }
}

extension Response {
    /// Make request conditional by checking request headers against either the modification date or eTag of content
    ///
    /// - Parameters:
    ///   - request: Request
    ///   - headers: Additional headers to write into response if returning a condition failed response
    ///   - eTag: ETag to test against request `If-None-Matched` and `If-Matched` headers
    ///   - modificationDate: Modification date to test against request `If-Modified-Since` and `If-Unmodified-Since` header
    ///   - noMatch: If all the conditions pass a closure that will return the desired Response.
    /// - Returns: Response
    public static func conditional(
        request: Request,
        headers: HTTPFields = [:],
        eTag: String? = nil,
        modificationDate: Date? = nil,
        noMatch: () async throws -> Response
    ) async throws -> Response {
        if let eTag {
            let ifNoneMatch = request.headers[values: .ifNoneMatch]
            if ifNoneMatch.count > 0 {
                if ifNoneMatch.contains(eTag) {
                    // Response status based on whether this is a read-only request ie GET or HEAD
                    let status: HTTPResponse.Status =
                        if request.method == .get || request.method == .head {
                            .notModified
                        } else {
                            .preconditionFailed
                        }
                    var headers = headers
                    headers[.eTag] = eTag
                    return Response(status: status, headers: headers)
                }
                // if an eTag was supplied and the `If-None-Match` contained eTags then
                // we shouldn't do a modification data check, so return now
                return try await noMatch()
            }
            if !request.headers[values: .ifMatch].contains(eTag) {
                return Response(status: .preconditionFailed, headers: headers)
            }
        }
        if let modificationDate {
            // `If-Modified-Since` headers are only applied to GET or HEAD requests
            if request.method == .get || request.method == .head {
                if let ifModifiedSinceHeader = request.headers[.ifModifiedSince] {
                    if let ifModifiedSinceDate = Date(httpHeader: ifModifiedSinceHeader) {
                        // round modification date of file down to seconds for comparison
                        let modificationDateTimeInterval = modificationDate.timeIntervalSince1970.rounded(.down)
                        let ifModifiedSinceDateTimeInterval = ifModifiedSinceDate.timeIntervalSince1970
                        if modificationDateTimeInterval <= ifModifiedSinceDateTimeInterval {
                            var headers = headers
                            headers[.lastModified] = modificationDate.httpHeader
                            return Response(status: .notModified, headers: headers)
                        }
                    }
                }
            }
            if let ifUnmodifiedSinceHeader = request.headers[.ifUnmodifiedSince] {
                if let ifUnmodifiedSinceDate = Date(httpHeader: ifUnmodifiedSinceHeader) {
                    // round modification date of file down to seconds for comparison
                    let modificationDateTimeInterval = modificationDate.timeIntervalSince1970.rounded(.down)
                    let ifUnmodifiedSinceDateTimeInterval = ifUnmodifiedSinceDate.timeIntervalSince1970
                    if modificationDateTimeInterval > ifUnmodifiedSinceDateTimeInterval {
                        var headers = headers
                        headers[.lastModified] = modificationDate.httpHeader
                        return Response(status: .preconditionFailed, headers: headers)
                    }
                }
            }
        }
        return try await noMatch()
    }
}
