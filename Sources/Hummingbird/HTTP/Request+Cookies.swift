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

extension Request {
    /// access cookies from request. When accessing this for the first time the Cookies struct will be created
    /// allows invalid cookies for compatibility reasons
    public var cookies: Cookies {
        Cookies(from: self, validate: false)
    }
}
