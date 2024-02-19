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

/// Context data required by `HBRouterBuilder`
public struct HBRouterBuilderContext: Sendable {
    /// remaining path components to match
    @usableFromInline
    var remainingPathComponents: ArraySlice<Substring>

    public init() {
        self.remainingPathComponents = []
    }
}

/// Protocol that all request contexts used with HBRouterBuilder should conform to.
public protocol HBRouterRequestContext: HBBaseRequestContext {
    var routerContext: HBRouterBuilderContext { get set }
}

/// Basic implementation of a context that can be used with `HBRouterBuilder``
public struct HBBasicRouterRequestContext: HBRequestContext, HBRouterRequestContext {
    public var routerContext: HBRouterBuilderContext
    public var coreContext: HBCoreRequestContext

    public init(channel: Channel, logger: Logger) {
        self.coreContext = .init(allocator: channel.allocator, logger: logger)
        self.routerContext = .init()
    }
}
