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

import NIOCore

public struct RouterResponder<Context: RequestContext>: HTTPResponder {
    @usableFromInline
    let trie: RouterTrie<EndpointResponders<Context>>

    @usableFromInline
    let notFoundResponder: any HTTPResponder<Context>

    @usableFromInline
    let options: RouterOptions

    init(
        context: Context.Type,
        trie: RouterPathTrieBuilder<EndpointResponders<Context>>,
        options: RouterOptions,
        notFoundResponder: any HTTPResponder<Context>
    ) {
        self.trie = RouterTrie(base: trie)
        self.options = options
        self.notFoundResponder = notFoundResponder
    }

    /// Respond to request by calling correct handler
    /// - Parameter request: HTTP request
    /// - Returns: EventLoopFuture that will be fulfilled with the Response
    @inlinable
    public func respond(to request: Request, context: Context) async throws -> Response {
        let path: String
        if self.options.contains(.caseInsensitive) {
            path = request.uri.path.lowercased()
        } else {
            path = request.uri.path
        }
        guard
            let (responderChain, parameters) = trie.resolve(path),
            let responder = responderChain.getResponder(for: request.method)
        else {
            return try await self.notFoundResponder.respond(to: request, context: context)
        }
        var context = context
        context.coreContext.parameters = parameters
        // store endpoint path in request (mainly for metrics)
        context.coreContext.endpointPath.value = responderChain.path
        return try await responder.respond(to: request, context: context)
    }
}
