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

extension HBResponse {
    /// Set cookie on response
    public mutating func setCookie(_ cookie: HBCookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}

extension HBEditedResponse {
    /// Set cookie on reponse patch
    ///
    /// Can be accessed via `request.response.setCookie(myCookie)`
    public mutating func setCookie(_ cookie: HBCookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}
