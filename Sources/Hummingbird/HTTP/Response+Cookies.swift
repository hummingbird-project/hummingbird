//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdCore

extension Response {
    /// Set cookie on response
    public mutating func setCookie(_ cookie: Cookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}

extension EditedResponse {
    /// Set cookie on reponse patch
    ///
    /// Can be accessed via `request.response.setCookie(myCookie)`
    public mutating func setCookie(_ cookie: Cookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}
