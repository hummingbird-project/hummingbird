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
import NIOCore
import NIOHTTP1
import ServiceContextModule

/// Router
public struct Router<Context: HBRequestContext, Handler: MiddlewareProtocol>: MiddlewareProtocol where Handler.Input == HBRequest, Handler.Output == HBResponse, Handler.Context == Context
{
    public typealias Input = HBRequest
    public typealias Output = HBResponse

    let handler: Handler

    public init(handler: Handler) {
        self.handler = handler
    }

    public init(@MiddlewareBuilder<Input, Output, Context> builder: () -> Handler) {
        self.handler = builder()
    }

    public init(context: Context.Type, @MiddlewareBuilder<Input, Output, Context> builder: () -> Handler) {
        self.handler = builder()
    }

    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        var context = context
        context.coreContext.remainingPathComponents = input.uri.path.split(separator: "/")[...]
        return try await self.handler.handle(input, context: context, next: next)
    }
}

/// extend Router to conform to HBResponder so we can use it to process `HBRequest``
extension Router: HBResponder where Handler.Input == HBRequest, Handler.Output == HBResponse {
    public func respond(to request: Input, context: Context) async throws -> Output {
        try await self.handle(request, context: context) { _, _ in
            throw HBHTTPError(.notFound)
        }
    }
}
