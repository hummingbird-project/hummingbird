//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdCore

@available(macOS 14, iOS 17, tvOS 17, *)
extension Response {
    /// Set cookie on response
    public mutating func setCookie(_ cookie: Cookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}

@available(macOS 14, iOS 17, tvOS 17, *)
extension EditedResponse {
    /// Set cookie on reponse patch
    ///
    /// Can be accessed via `request.response.setCookie(myCookie)`
    public mutating func setCookie(_ cookie: Cookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}
