//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdCore

extension Response {
    /// Specifies the type of redirect that the client should receive.
    public enum RedirectType: Sendable {
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
