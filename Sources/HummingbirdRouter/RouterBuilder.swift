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

    public init(allocator: ByteBufferAllocator, logger: Logger) {
        self.coreContext = .init(allocator: allocator, logger: logger)
        self.routerContext = .init()
    }
}

/// Router
public struct HBRouterBuilder<Context: HBRouterRequestContext, Handler: MiddlewareProtocol>: MiddlewareProtocol where Handler.Input == HBRequest, Handler.Output == HBResponse, Handler.Context == Context
{
    public typealias Input = HBRequest
    public typealias Output = HBResponse

    let handler: Handler

    public init(handler: Handler) {
        self.handler = handler
    }

    public init(context: Context.Type = Context.self, @MiddlewareFixedTypeBuilder<Input, Output, Context> builder: () -> Handler) {
        self.handler = builder()
    }

    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        var context = context
        context.routerContext.remainingPathComponents = input.uri.path.split(separator: "/")[...]
        return try await self.handler.handle(input, context: context, next: next)
    }
}

/// extend Router to conform to HBResponder so we can use it to process `HBRequest``
extension HBRouterBuilder: HBResponder {
    public func respond(to request: Input, context: Context) async throws -> Output {
        try await self.handle(request, context: context) { _, _ in
            throw HBHTTPError(.notFound)
        }
    }
}
