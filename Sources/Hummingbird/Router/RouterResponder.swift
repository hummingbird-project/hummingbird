//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Directs requests to handlers based on the request uri and method.
///
/// Conforms to `HBResponder` so need to provide its own implementation of
/// `func apply(to request: Request) -> EventLoopFuture<Response>`.
///
struct HBRouterResponder<Context: HBBaseRequestContext>: HBResponder {
    let trie: RouterPathTrie<HBEndpointResponders<Context>>
    let notFoundResponder: any HBResponder<Context>

    init(context: Context.Type, trie: RouterPathTrie<HBEndpointResponders<Context>>, notFoundResponder: any HBResponder<Context>) {
        self.trie = trie
        self.notFoundResponder = notFoundResponder
    }

    /// Respond to request by calling correct handler
    /// - Parameter request: HTTP request
    /// - Returns: EventLoopFuture that will be fulfilled with the Response
    public func respond(to request: HBRequest, context: Context) async throws -> HBResponse {
        let path = request.uri.path
        guard let result = trie.getValueAndParameters(path),
              let responder = result.value.getResponder(for: request.method)
        else {
            return try await self.notFoundResponder.respond(to: request, context: context)
        }
        var context = context
        if let parameters = result.parameters {
            context.coreContext.parameters = parameters
        }
        // store endpoint path in request (mainly for metrics)
        context.coreContext.endpointPath.value = result.value.path
        return try await responder.respond(to: request, context: context)
    }
}
