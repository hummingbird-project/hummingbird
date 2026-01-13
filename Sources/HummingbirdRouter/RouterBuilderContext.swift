//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import Hummingbird

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
public protocol RouterRequestContext: RequestContext {
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
