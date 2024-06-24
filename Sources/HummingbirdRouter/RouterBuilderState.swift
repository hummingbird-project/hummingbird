//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceContextModule

/// Router builder state used when building Router
internal struct RouterBuilderState {
    var routeGroupPath: String = ""
    let options: RouterBuilderOptions
}

extension ServiceContext {
    enum RouterBuilderStateKey: ServiceContextKey {
        typealias Value = RouterBuilderState
    }

    /// Current RouteGroup path. This is used to propagate the route path down
    /// through the Router result builder
    internal var routerBuildState: RouterBuilderState? {
        get {
            self[RouterBuilderStateKey.self]
        }
        set {
            self[RouterBuilderStateKey.self] = newValue
        }
    }
}
