//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Hummingbird

/// Router builder state used when building Router
internal struct RouterBuilderState {
    @TaskLocal static var current: RouterBuilderState?
    var routeGroupPath: RouterPath = ""
    let options: RouterBuilderOptions
}
