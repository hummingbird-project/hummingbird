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

import MiddlewareModule
import ServiceContextModule

/// Matches remaining path components and request method
public struct Route<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: MiddlewareProtocol {
    public typealias Input = HBRequest
    public typealias Output = HBResponse
    public typealias Context = Context
    public typealias Handler = @Sendable (Input, Context) async throws -> RouteOutput

    let fullPath: String
    let routerPath: RouterPath
    let method: HTTPMethod
    let handler: Handler

    public init(_ method: HTTPMethod, _ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = method
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }

    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        if input.method == self.method, let context = self.routerPath.matchAll(context) {
            context.coreContext.resolvedEndpointPath.value = self.fullPath
            return try await self.handler(input, context).response(from: input, context: context)
        }
        return try await next(input, context)
    }
}
