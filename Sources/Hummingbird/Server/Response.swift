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
import NIOHTTP1

/// Holds all the required to generate a HTTP Response
public struct HBResponse: HBSendableExtensible {
    /// response status
    public var status: HTTPResponseStatus
    /// response headers
    public var headers: HTTPHeaders
    /// response body
    public var body: HBResponseBody
    /// Response extensions
    public var extensions: HBSendableExtensions<HBResponse>

    /// Create an `HBResponse`
    ///
    /// - Parameters:
    ///   - status: response status
    ///   - headers: response headers
    ///   - body: response body
    public init(status: HTTPResponseStatus, headers: HTTPHeaders = [:], body: HBResponseBody = .empty) {
        self.status = status
        self.headers = headers
        self.body = body
        self.extensions = .init()
    }
}

extension HBResponse {
    /// Specifies the type of redirect that the client should receive.
    public enum RedirectType {
        /// `301 moved permanently`: The URL of the requested resource has been changed permanently.
        /// The new URL is iven in the response.
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

        /// Associated `HTTPResponseStatus` for this redirect type.
        public var status: HTTPResponseStatus {
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
    /// - Returns: HBResponse with redirection
    public static func redirect(to location: String, type: RedirectType = .normal) -> HBResponse {
        return .init(status: type.status, headers: ["location": location])
    }
}

extension HBResponse: CustomStringConvertible {
    public var description: String {
        "status: \(self.status), headers: \(self.headers), body: \(self.body)"
    }
}

#if compiler(>=5.6)
extension HBResponse: Sendable {}
#endif
