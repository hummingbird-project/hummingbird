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

/// Protocol for all route handlers, that match remaining path components and request method
public protocol RouteProtocol: MiddlewareProtocol where Input == HBRequest, Output == HBResponse, Context: HBRequestContext {
    associatedtype RouteOutput: HBResponseGenerator

    var fullPath: String { get }
    var routerPath: RouterPath { get }
    var method: HTTPMethod { get }
    var handler: Handler { get }

    typealias Handler = @Sendable (Input, Context) async throws -> RouteOutput
}

extension RouteProtocol {
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        if input.method == self.method, let context = self.routerPath.matchAll(context) {
            context.coreContext.resolvedEndpointPath.value = self.fullPath
            return try await self.handler(input, context).response(from: input, context: context)
        }
        return try await next(input, context)
    }
}

/// Generic route handler that
public struct Route<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteProtocol {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPMethod
    public let handler: Handler

    public init(_ method: HTTPMethod, _ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = method
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }
}

/// GET route handler
public struct Get<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteProtocol {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPMethod
    public let handler: Handler

    public init(_ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = .GET
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }
}

/// HEAD route handler
public struct Head<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteProtocol {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPMethod
    public let handler: Handler

    public init(_ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = .HEAD
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }
}

/// PUT route handler
public struct Put<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteProtocol {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPMethod
    public let handler: Handler

    public init(_ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = .PUT
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }
}

/// POST route handler
public struct Post<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteProtocol {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPMethod
    public let handler: Handler

    public init(_ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = .POST
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }
}

/// PATCH route handler
public struct Patch<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteProtocol {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPMethod
    public let handler: Handler

    public init(_ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = .PATCH
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }
}

/// DELETE route handler
public struct Delete<RouteOutput: HBResponseGenerator, Context: HBRequestContext>: RouteProtocol {
    public let fullPath: String
    public let routerPath: RouterPath
    public let method: HTTPMethod
    public let handler: Handler

    public init(_ routerPath: RouterPath = "", handler: @escaping Handler) {
        self.method = .DELETE
        self.routerPath = routerPath
        self.handler = handler
        let parentGroupPath = ServiceContext.current?.routeGroupPath ?? ""
        self.fullPath = "\(parentGroupPath)/\(self.routerPath)"
    }
}
