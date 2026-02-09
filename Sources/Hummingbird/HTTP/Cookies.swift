//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

/// Structure holding an array of cookies
///
/// Cookies can be accessed from request via `Request.cookies`.
@available(iOS 16, *)
public struct Cookies: Sendable {
    /// Construct cookies accessor from `Request`
    /// - Parameter request: request to get cookies from
    init(from request: Request) {
        self = Cookies(from: request.headers[values: .cookie])
    }

    package init(from cookieHeaders: [String]) {
        self.cookieStrings = cookieHeaders.flatMap { $0.splitSequence(separator: ";").map { $0.drop { $0.isWhitespace } } }
    }

    /// access cookies via dictionary subscript
    public subscript(_ key: String) -> Cookie? {
        guard
            let cookieString = cookieStrings.first(where: {
                guard let cookieName = Cookie.getName(from: $0) else { return false }
                return cookieName == key
            })
        else {
            return nil
        }
        return Cookie(from: cookieString)
    }

    var cookieStrings: [Substring]
}
