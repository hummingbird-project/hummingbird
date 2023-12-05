//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird
import ServiceContextModule

extension ServiceContext {
    enum RouteGroupPathKey: ServiceContextKey {
        typealias Value = String
    }

    /// Current RouteGroup path. This is used to propagate the route path down
    /// through the Router result builder
    public internal(set) var routeGroupPath: String? {
        get {
            self[RouteGroupPathKey.self]
        }
        set {
            self[RouteGroupPathKey.self] = newValue
        }
    }
}

public struct RouteGroup<Context: HBRouterRequestContext, Handler: MiddlewareProtocol>: HBMiddlewareProtocol where Handler.Input == HBRequest, Handler.Output == HBResponse, Handler.Context == Context {
    public typealias Input = HBRequest
    public typealias Output = HBResponse

    @usableFromInline
    var routerPath: RouterPath
    @usableFromInline
    var handler: Handler

    public init(
        _ routerPath: RouterPath = "",
        context: Context.Type = Context.self,
        @MiddlewareFixedTypeBuilder<HBRequest, HBResponse, Context> builder: () -> Handler
    ) {
        self.routerPath = routerPath
        var serviceContext = ServiceContext.current ?? ServiceContext.topLevel
        let parentGroupPath = serviceContext.routeGroupPath ?? ""
        serviceContext.routeGroupPath = "\(parentGroupPath)/\(self.routerPath)"
        self.handler = ServiceContext.$current.withValue(serviceContext) {
            builder()
        }
    }

    @inlinable
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        if let updatedContext = self.routerPath.matchPrefix(context) {
            return try await self.handler.handle(input, context: updatedContext) { input, _ in
                try await next(input, context)
            }
        }
        return try await next(input, context)
    }
}
