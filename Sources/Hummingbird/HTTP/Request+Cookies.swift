//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdCore

extension Request {
    /// access cookies from request. When accessing this for the first time the Cookies struct will be created
    public var cookies: Cookies {
        Cookies(from: self)
    }
}
