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

/// Structure holding an array of cookies
///
/// Cookies can be accessed from request via `Request.cookies`.
public struct Cookies: Sendable {
    /// Construct cookies accessor from `Request`
    /// - Parameter request: request to get cookies from
    /// - Parameter validate: cookies are nil if invalid
    init(from request: Request, validate: Bool = true) {
        self.cookieStrings = request.headers[values: .cookie].flatMap {
            $0.split(separator: ";").map { $0.drop { $0.isWhitespace } }
        }
        self.validate = validate
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
        return try? Cookie(from: cookieString, validate: validate)
    }

    var cookieStrings: [Substring]
    var validate: Bool
}
