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

public struct HBRouterContext {
    /// remaining path components to match
    @usableFromInline
    var remainingPathComponents: ArraySlice<Substring>

    init() {
        self.remainingPathComponents = []
    }
}

/// Protocol that all request contexts used with HBRouterBuilder should conform to.
public protocol HBRouterRequestContext: HBBaseRequestContext {
    var routerContext: HBRouterContext { get set }
}

/// Router
public struct HBRouter<Context: HBRouterRequestContext, Handler: MiddlewareProtocol>: MiddlewareProtocol where Handler.Input == HBRequest, Handler.Output == HBResponse, Handler.Context == Context
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
extension HBRouter: HBResponder {
    public func respond(to request: Input, context: Context) async throws -> Output {
        try await self.handle(request, context: context) { _, _ in
            throw HBHTTPError(.notFound)
        }
    }
}
