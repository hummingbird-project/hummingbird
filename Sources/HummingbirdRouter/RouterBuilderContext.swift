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

import Hummingbird
import Logging
import NIOCore

/// Context data required by `RouterBuilder`
public struct RouterBuilderContext: Sendable {
    /// remaining path components to match
    @usableFromInline
    var remainingPathComponents: ArraySlice<Substring>

    public init() {
        self.remainingPathComponents = []
    }
}

/// Protocol that all request contexts used with RouterBuilder should conform to.
public protocol RouterRequestContext: BaseRequestContext {
    var routerContext: RouterBuilderContext { get set }
}

/// Basic implementation of a context that can be used with `RouterBuilder``
public struct BasicRouterRequestContext: RequestContext, RouterRequestContext {
    public var routerContext: RouterBuilderContext
    public var coreContext: CoreRequestContextStorage

    public init(source: Source) {
        self.coreContext = .init(source: source)
        self.routerContext = .init()
    }
}
