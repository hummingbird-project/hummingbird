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

extension Response {
    /// Sets a ``Cookie`` on the ``Response``
    public mutating func setCookie(_ cookie: Cookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}

extension EditedResponse {
    /// Set ``Cookie`` on an ``EditedResponse``
    public mutating func setCookie(_ cookie: Cookie) {
        self.headers[values: .setCookie].append(cookie.description)
    }
}
