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
/// Cookies can be accessed from request via `HBRequest.cookies`.
public struct HBCookies: Sendable {
    /// Construct cookies accessor from `HBRequest`
    /// - Parameter request: request to get cookies from
    init(from request: HBRequest) {
        self.cookieStrings = request.headers[values: .cookie].flatMap {
            return $0.split(separator: ";").map { $0.drop { $0.isWhitespace } }
        }
    }

    /// access cookies via dictionary subscript
    public subscript(_ key: String) -> HBCookie? {
        guard let cookieString = cookieStrings.first(where: {
            guard let cookieName = HBCookie.getName(from: $0) else { return false }
            return cookieName == key
        }) else {
            return nil
        }
        return HBCookie(from: cookieString)
    }

    var cookieStrings: [Substring]
}
